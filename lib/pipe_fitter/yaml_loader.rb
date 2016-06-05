require "yaml"
require "erb"

module PipeFitter
  class YamlLoader
    class << self
      def load(filename, context_filename = nil)
        context = context_filename.nil? ? nil : YAML.load_file(context_filename)
        YAML.load(eval_erb(filename, context)) || {}
      end

      def include_yaml(filepath, indent = 1)
        load(filepath).to_yaml.chomp.gsub("---", "").gsub("\n", "\n" + "  " * indent)
      end

      private

      def eval_erb(filename, context = nil)
        context ||= {}
        ERB.new(File.read(filename)).result(binding)
      end
    end
  end
end
