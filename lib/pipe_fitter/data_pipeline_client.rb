require "aws-sdk"

module PipeFitter
  class NoSuchPipelineError < StandardError; end

  class DataPipelineClient
    def initialize(options)
      @options = options.map { |k, v| [k.to_sym, v] }.to_h
    end

    def register(definition_file)
      p = Pipeline.load_yaml(definition_file)
      create(p)
    end

    def diff(pipeline_id, definition_file, format = :color)
      p = Pipeline.load_yaml(definition_file)
      definition(pipeline_id).diff(p, format.to_sym)
    end

    def update(pipeline_id, definition_file)
      p = Pipeline.load_yaml(definition_file)
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
      p = parameter_file ? Pipeline.load_yaml(parameter_file) : Pipeline.new
      exec(:activate_pipeline, p.activate_opts(pipeline_id, start_timestamp)).to_h
    end

    private

    def description(pipeline_id)
      desc = exec(:describe_pipelines, pipeline_ids: [pipeline_id]).pipeline_description_list.first
      raise NoSuchPipelineError, pipeline_id if desc.nil?
      desc
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

    def client
      @client ||= Aws::DataPipeline::Client.new(sdk_opts)
    end

    def sdk_opts
      keys = %i(region profile).freeze
      @options.select { |k, _| keys.include?(k) }
    end
  end
end
