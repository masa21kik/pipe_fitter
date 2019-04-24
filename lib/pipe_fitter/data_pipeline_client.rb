require "aws-sdk-datapipeline"
require "aws-sdk-s3"
require "uri"
require "s3diff"

module PipeFitter
  class NoSuchPipelineError < StandardError; end

  class DataPipelineClient
    def initialize(options)
      @options = options.map { |k, v| [k.to_sym, v] }.to_h
    end

    def register(definition_file)
      p = load_pipeline(definition_file)
      create(p)
    end

    def diff(pipeline_id, definition_file, format = :color)
      p = load_pipeline(definition_file)
      [
        definition(pipeline_id).diff(p, format.to_sym),
        diff_deploy_files(definition_file, format.to_sym),
      ].compact.reject(&:empty?).join("\n")
    end

    def update(pipeline_id, definition_file)
      upload_deploy_files(definition_file)
      p = load_pipeline(definition_file)
      put_definition(pipeline_id, p)
    end

    def definition(pipeline_id)
      res = exec(:get_pipeline_definition, pipeline_id: pipeline_id)
      desc = description(pipeline_id)
      Pipeline.create(res.to_h, desc.to_h)
    end

    def put_definition(pipeline_id, pipeline)
      sync_tags(pipeline_id, pipeline)
      exec(:put_pipeline_definition, pipeline.put_definition_opts(pipeline_id)).to_h
    end

    def create(pipeline)
      res = exec(:create_pipeline, pipeline.create_opts)
      [res.pipeline_id, put_definition(res.pipeline_id, pipeline)]
    end

    def activate(pipeline_id, parameter_file, start_timestamp)
      p = parameter_file ? load_pipeline(parameter_file) : Pipeline.new
      exec(:activate_pipeline, p.activate_opts(pipeline_id, start_timestamp)).to_h
    end

    def find_registered(definition_file)
      p = load_pipeline(definition_file)
      pls = list_pipelines.select { |l| l.name == p.pipeline_description.name }
      res = pls.find do |pl|
        d = Pipeline::PipelineDescription.create(description(pl.id))
        d.unique_id == p.pipeline_description.unique_id
      end
      res
    end

    def diff_deploy_files(definition_file, format = :color)
      p = load_pipeline(definition_file)
      p.deploy_files.map do |df|
        c = S3diff::Comparator.new(df[:dst], df[:src], sdk_opts)
        c.diff.to_s(format.to_sym) unless c.same?
      end.compact
    end

    def upload_deploy_files(definition_file)
      p = load_pipeline(definition_file)
      p.deploy_files.each do |df|
        put_object(df[:src], df[:dst])
      end
    end

    private

    def load_pipeline(definition_file)
      Pipeline.load_yaml(definition_file)
    end

    def description(pipeline_id)
      desc = exec(:describe_pipelines, pipeline_ids: [pipeline_id]).pipeline_description_list.first
      raise NoSuchPipelineError, pipeline_id if desc.nil?
      desc
    end

    def list_pipelines
      res = exec(:list_pipelines)
      pls = res.pipeline_id_list
      while res.has_more_results
        res = exec(:list_pipelines, marker: res.marker)
        pls.concat(res.pipeline_id_list)
      end
      pls
    end

    def sync_tags(pipeline_id, pipeline)
      p = definition(pipeline_id)
      return if p.tags == pipeline.tags
      exec(:remove_tags, p.remove_tags_opts(pipeline_id)) unless p.tags.empty?
      exec(:add_tags, pipeline.add_tags_opts(pipeline_id)) unless pipeline.tags.empty?
    end

    def exec(method, *args)
      client.send(method, *args)
    rescue Aws::DataPipeline::Errors::PipelineNotFoundException, Aws::DataPipeline::Errors::PipelineDeletedException => e
      raise NoSuchPipelineError, args.unshift(e.class)
    end

    def put_object(src, dst)
      u = URI.parse(dst)
      s3client.put_object(
        body: File.read(src),
        bucket: u.host,
        key: u.path.sub(%r{^/}, "")
      )
      puts "put #{src} to #{dst}"
    end

    def client
      @client ||= Aws::DataPipeline::Client.new(sdk_opts)
    end

    def s3client
      @s3client ||= Aws::S3::Client.new(sdk_opts)
    end

    def sdk_opts
      keys = %i(region profile).freeze
      @options.select { |k, _| keys.include?(k) }
    end
  end
end
