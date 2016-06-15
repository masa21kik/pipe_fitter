require "yaml"
require "erb"

module PipeFitter
  class YamlLoader
    class << self
      def load(filename, context_filename = nil)
        context = context_filename.nil? ? nil : YAML.load_file(context_filename)
        YAML.load(eval_erb(filename, context)) || {}
      end

      def include_template(filename, context = {})
        eval_erb(filename, context)
      end

      private

      def eval_erb(filename, context = nil)
        context ||= {}
        ERB.new(File.read(filename), nil, "-").result(binding).strip
      end
    end
  end
end
