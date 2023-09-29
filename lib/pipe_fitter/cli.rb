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

      diff = client.diff_deploy_files(definition_file)
      unless diff.empty?
        puts diff.join("\n")
        print "\nReally upload deploy_files? [y/N] : "
        abort("Upload deploy_files were canceled") if $stdin.gets.chomp !~ /^y$/i
        client.upload_deploy_files(definition_file)
      end
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

    desc "activate", "Activate pipeline"
    option :pipeline_id, type: :string, required: true, aliases: "i"
    option :parameter_file, type: :string, required: false, aliases: "p"
    option :start_timestamp, type: :string, required: false, aliases: "t"
    def activate
      t = options[:start_timestamp] ? Time.parse(options[:start_timestamp]) : nil
      puts client.activate(options[:pipeline_id], options[:parameter_file], t)
    end

    desc "show", "Show pipeline setting in YAML format"
    option :parameter_file, type: :string, required: false, aliases: "p"
    def show(definition_file)
      puts Pipeline.load_yaml(definition_file).to_yaml
    end

    desc "find", "Find pipeline besed on name and uniqueId"
    def find(definition_file)
      puts client.find_registered(definition_file).to_h.to_json
    end

    desc "find_diff", "Find pipeline besed on name and uniqueId, show diff"
    option :format, type: :string, default: "color", aliases: "f"
    def find_diff(definition_file)
      p = client.find_registered(definition_file)
      abort("Pipeline is not registered") if p.nil?
      puts client.diff(p.id, definition_file, options[:format])
      puts p.to_h.to_json
    end

    desc "find_update", "Find pipeline besed on name and uniqueId, update pipeline definition"
    option :force_update, type: :boolean, aliases: "f"
    def find_update(definition_file)
      p = client.find_registered(definition_file)
      abort("Pipeline is not registered") if p.nil?
      unless options[:force_update]
        puts client.diff(p.id, definition_file)
        print "\nReally update pipeline definition? [y/N] : "
        abort("Update was canceled") if $stdin.gets.chomp !~ /^y$/i
      end
      res = client.update(p.id, definition_file)
      puts JSON.pretty_generate(res)
      puts p.to_h.to_json
    end

    desc "diff_deploy_files DEFINITION_FILE", "Show deploy files differences"
    option :format, type: :string, default: "color", aliases: "f"
    def diff_deploy_files(definition_file)
      client.diff_deploy_files(definition_file, options[:format]).each do |d|
        puts d
      end
    end

    desc "upload_deploy_files DEFINITION_FILE", "Upload deploy files"
    def upload_deploy_files(definition_file)
      client.upload_deploy_files(definition_file)
    end

    private

    def client
      @client ||= DataPipelineClient.new(options)
    end
  end
end
