require "yaml"
require "hashie"
require "diffy"
require "pathname"

module PipeFitter
  class Pipeline
    def self.create(definition_from_api, description_from_api)
      new(PipelineObjects.create(definition_from_api[:pipeline_objects]),
          ParameterObjects.create(definition_from_api[:parameter_objects]),
          ParameterValues.create(definition_from_api[:parameter_values]),
          PipelineDescription.create(description_from_api))
    end

    def self.load_yaml(filename)
      filepath = Pathname.new(filename)
      yml = YamlLoader.load(filepath)
      new(PipelineObjects.new(yml["pipeline_objects"]),
          ParameterObjects.new(yml["parameter_objects"]),
          ParameterValues.new(yml["parameter_values"]),
          PipelineDescription.new(yml["pipeline_description"]))
    end

    def initialize(pipeline_objects, parameter_objects, parameter_values, pipeline_description)
      @pipeline_objects = pipeline_objects
      @parameter_objects = parameter_objects
      @parameter_values = parameter_values
      @pipeline_description = pipeline_description
    end

    def tags
      @pipeline_description.tags
    end

    def to_yaml
      {
        "pipeline_description" => @pipeline_description.to_objs,
        "pipeline_objects" => @pipeline_objects.to_objs,
        "parameter_objects" => @parameter_objects.to_objs,
        "parameter_values" => @parameter_values.to_objs,
      }.to_yaml
    end

    def put_definition_opts(pipeline_id)
      {
        pipeline_id: pipeline_id,
        pipeline_objects: @pipeline_objects.to_api_opts,
        parameter_objects: @parameter_objects.to_api_opts,
        parameter_values: @parameter_values.to_api_opts,
      }
    end

    def add_tags_opts(pipeline_id)
      { pipeline_id: pipeline_id, tags: @pipeline_description.tags_opts }
    end

    def remove_tags_opts(pipeline_id)
      { pipeline_id: pipeline_id, tag_keys: @pipeline_description.tag_keys }
    end

    def diff(other, format = nil)
      Diffy::Diff.new(self.to_yaml, other.to_yaml).to_s(format)
    end

    class PipelineBaseObjects
      def initialize(objs)
        @objs = case objs
                when Array then objs.map { |obj| symbolize_keys(obj) }
                else symbolize_keys(objs) || {}
                end
      end

      def to_objs
        case @objs
        when Array then @objs.map { |obj| stringify_keys(obj) }
        else stringify_keys(@objs)
        end
      end

      private

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

      private_class_method def self.update_hash(base, key, value)
        if base.key?(key)
          base[key] = [base[key]] unless base[key].is_a?(Array)
          base[key] << value
          base[key].sort!
        else
          base[key] = value
        end
        base
      end

      def split_object(obj, skip_keys)
        res = []
        obj.each do |k, v|
          next if skip_keys.include?(k)
          (v.is_a?(Array) ? v : [v]).each do |vv|
            if vv.is_a?(Hash) && vv.key?(:ref)
              res << { key: k, ref_value: vv[:ref] }
            else
              res << { key: k, string_value: vv }
            end
          end
        end
        res
      end
    end

    class PipelineObjects < PipelineBaseObjects
      def self.create(api_res)
        objs = api_res.map(&:to_h).sort_by { |obj| obj[:id] }.map do |obj|
          base = { id: obj[:id], name: obj[:name] }
          obj[:fields].sort_by { |f| f[:key] }.inject(base) do |a, e|
            update_hash(a, e[:key].to_sym, e[:string_value] || { ref: e[:ref_value] })
          end
        end
        new(objs)
      end

      def to_api_opts
        @objs.map do |obj|
          { id: obj[:id], name: obj[:name], fields: split_object(obj, %i(id name)) }
        end
      end
    end

    class ParameterObjects < PipelineBaseObjects
      def self.create(api_res)
        objs = api_res.map(&:to_h).sort_by { |obj| obj[:id] }.map do |obj|
          base = { id: obj[:id] }
          obj[:attributes].sort_by { |a| a[:key] }.inject(base) do |a, e|
            update_hash(a, e[:key].to_sym, e[:string_value])
          end
        end
        new(objs)
      end

      def to_api_opts
        @objs.map do |obj|
          { id: obj[:id], attributes: split_object(obj, %i(id)) }
        end
      end
    end

    class ParameterValues < PipelineBaseObjects
      def self.create(api_res)
        objs = (api_res || []).sort_by { |obj| [obj[:id], obj[:string_value]] }.map do |obj|
          { obj[:id].to_sym => obj[:string_value] }
        end
        new(objs)
      end

      def to_api_opts
        @objs.map do |e|
          e.map do |k, v|
            { id: k, string_value: v }
          end
        end.flatten
      end
    end

    class PipelineDescription < PipelineBaseObjects
      def self.create(api_res)
        objs = {
          pipeline_id: api_res[:pipeline_id],
          name: api_res[:name],
          description: api_res[:description],
        }
        objs[:tags] = api_res[:tags].map { |e| { e[:key].to_sym => e[:value] } }
        api_res[:fields].inject(objs) do |a, e|
          a.update(e[:key].to_sym => (e[:string_value] || { ref: e[:ref_value] } ))
        end
        new(objs)
      end

      def to_objs
        keys = %i(name description tags uniqueId)
        stringify_keys(@objs.select { |k, _| keys.include?(k) })
      end

      def tags
        @objs[:tags]
      end

      def tags_opts
        @objs[:tags].map { |e| e.map { |k, v| { key: k, value: v } } }.flatten
      end

      def tag_keys
        @objs[:tags].map(&keys).flatten
      end
    end
  end
end
