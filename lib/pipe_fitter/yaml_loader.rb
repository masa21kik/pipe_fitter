require "yaml"
require "erb"
require "pathname"

module PipeFitter
  class YamlLoader
    def initialize
      @search_path = [Pathname.new(".")]
    end

    def load(filename)
      @search_path.unshift(Pathname.new(filename).dirname)
      YAML.load(eval_erb(filename)) || {}
    end

    def include_template(filename, context = {})
      dir = @search_path.find { |p| p.join(filename).exist? }
      path = dir.nil? ? filename : dir.join(filename)
      eval_erb(path, context).gsub("\n", "\n" + " " * (context[:indent] || 0))
    end

    private

    def eval_erb(filename, context = {})
      ERB.new(File.read(filename), nil, "-").result(binding).strip
    end
  end
end
