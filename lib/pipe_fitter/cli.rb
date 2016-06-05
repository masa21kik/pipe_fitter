require "pipe_fitter"
require "thor"

module PipeFitter
  class Cli < Thor
    class_option :region, type: :string
    class_option :profile, type: :string

    desc "export", "Export pipeline definition"
    option :pipeline_id, type: :string, required: true, aliases: "i"
    def export
      puts client.definition(options[:pipeline_id]).to_yaml
    end

    desc "register DEFINITION_FILE", "Register pipeline"
    def register(definition_file)
      id, res = client.register(definition_file)
      puts id, JSON.pretty_generate(res)
    end

    desc "diff DEFINITION_FILE", "Show pipeline difference"
    option :pipeline_id, type: :string, required: true, aliases: "i"
    option :format, type: :string, default: "color", aliases: "f"
    def diff(definition_file)
      puts client.diff(options[:pipeline_id], definition_file, options[:format])
    end

    desc "update DEFINITION_FILE", "Update pipeline definition"
    option :pipeline_id, type: :string, required: true, aliases: "i"
    def update(definition_file)
      res = client.update(options[:pipeline_id], definition_file)
      puts JSON.pretty_generate(res)
    end

    desc "activate pipeline", "Activate pipeline"
    option :pipeline_id, type: :string, required: true, aliases: "i"
    option :parameter_values, type: :hash, required: false, aliases: "p"
    option :start_timestamp, type: :string, required: false, aliases: "t"
    def activate
      t = options[:start_timestamp] ? Time.parse(options[:start_timestamp]) : nil
      puts client.activate(options[:pipeline_id], options[:parameter_values], t)
    end

    private

    def client
      @client ||= DataPipelineClient.new(options)
    end
  end
end