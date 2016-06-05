require "yaml"
require "hashie"
require "diffy"
require "pathname"

module PipeFitter
  class Pipeline
    class << self
      def load_yaml(filename)
        filepath = Pathname.new(filename)
        desc = YamlLoader.load(filepath)
        definition = desc.delete("definition")
        Pipeline.new(definition, desc)
      end
    end

    DESCRIPTION_KEYS = %w(name tags unique_id description).freeze
    Diffy::Diff.default_options.merge!(diff: "-u", include_diff_info: true)

    def initialize(definition, description = {})
      @definition = Hashie::Mash.new(definition)
      @full_description = Hashie::Mash.new(description).tap do |h|
        if (fs = h[:fields]) && (f = fs.find { |e| e[:key] == "uniqueId" }) && f.key?(:string_value)
          h.unique_id ||= f[:string_value]
        end
      end
      @description = Hashie::Mash.new(@full_description.select { |k, v| DESCRIPTION_KEYS.include?(k) && !v.nil? })
    end

    def to_yaml
      stringify_keys(@description.merge("definition" => sorted_definition)).to_yaml
    end

    def create_opts
      symbolize_keys(@description)
    end

    def put_definition_opts(id = nil)
      base = { pipeline_id: id || pipeline_id }
      base.merge(symbolize_keys(@definition))
    end

    def add_tags_opts(id = nil)
      { pipeline_id: id || pipeline_id, tags: @full_description.tags }
    end

    def remove_tags_opts(id = nil)
      { pipeline_id: id || pipeline_id, tag_keys: @full_description.tags.map { |e| e["key"] } }
    end

    def activate_opts(parameter_values, start_timestamp = nil, id = nil)
      pv = (parameter_values || {}).map { |k, v| { "id" => k.to_s, "string_value" => v.to_s } }
      { pipeline_id: id || pipeline_id, parameter_values: pv, start_timestamp: start_timestamp }.select { |_, v| !v.nil? }
    end

    def pipeline_id
      @full_description.pipeline_id
    end

    def name
      @full_description.name
    end

    def tags
      @full_description.tags
    end

    def diff(other, format = nil)
      Diffy::Diff.new(self.to_yaml, other.to_yaml).to_s(format)
    end

    private

    def sorted_definition
      top_keys = %w(pipeline_objects parameter_objects parameter_values).freeze
      obj_keys = %w(id name fields).freeze
      field_keys = %w(key string_value ref_value).freeze

      d = @definition.sort_by { |k, _| [top_keys.index(k) || top_keys.size, k] }.to_h
      top_keys.each do |k|
        next if !d[k].is_a?(Array) || d[k].empty?
        d[k] = d[k].sort_by { |e| e["id"] }
        d[k].map! do |v|
          v["fields"] = v["fields"].sort_by { |e| e["key"] }
          v["fields"].map! { |vv| vv.sort_by { |kk, _| field_keys.index(kk) }.to_h }
          v.sort_by { |kk, _| obj_keys.index(kk) }.to_h
        end
      end
      d
    end

    def stringify_keys(val)
      modify_keys_recursively(val, __method__)
    end

    def symbolize_keys(val)
      modify_keys_recursively(val, __method__)
    end

    def modify_keys_recursively(val, method)
      return val unless val.is_a?(Hash)
      h = Hashie.send(method, val.to_h)
      h.each do |k, v|
        case v
        when Array then h[k].map! { |e| self.send(method, e) }
        when Hash then h[k] = self.send(method, v)
        end
      end
      h
    end
  end
end
