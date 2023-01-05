require "yaml"
require "erb"
require "pathname"
require "tempfile"

module PipeFitter
  class YamlLoader
    def initialize
      @search_path = [Pathname.new(".")]
    end

    def load(filename)
      @search_path.unshift(Pathname.new(filename).dirname)
      text = eval_erb(grep_v(filename, /^\s*#/))
      YAML.load(text, aliases: true) || {}
    rescue ArgumentError
      YAML.load(text) || {}
    rescue Psych::SyntaxError => e
      text.split("\n").each_with_index do |l, i|
        mark = (e.line == i + 1) ? "*" : " "
        $stderr.puts format("%s%4d| %s", mark, i + 1, l)
      end
      raise e
    end

    def include_template(filename, context = {})
      path = search_filepath(filename)
      eval_erb(File.read(path), context)
        .gsub("\n", "\n" + " " * (context[:indent] || 0))
    end

    def search_filepath(filename)
      dir = @search_path.find { |p| p.join(filename).exist? }
      if dir
        dir.join(filename)
      elsif File.exists?(filename)
        filename
      end
    end

    private

    def eval_erb(data, context = {})
      ERB.new(data, trim_mode: "-").result(binding).strip
    end

    def grep_v(filename, pattern)
      File.open(filename).select { |l| l !~ pattern }.join
    end
  end
end
