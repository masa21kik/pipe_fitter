require_relative "helper"

class YamlLoaderTest < Test::Unit::TestCase
  sub_test_case "load" do
    data("empty" => ["", {}],
         "normal" => [
           "---\npd:\n  name: foo\n  description: bar\npo: []",
           { "pd" =>  { "name" => "foo", "description" => "bar" }, "po" => [] }
         ],
         "erb" => [
           "---\npd:\n  name: foo\n  description: <%= ENV['DESC'] %>\npo: []",
           { "pd" =>  { "name" => "foo", "description" => "bar baz" }, "po" => [] }
         ],
         "erb_commented_out" => [
           "---\npd:\n  name: foo\n#  description: <%= ENV['DESC'] %>\npo: []",
           { "pd" =>  { "name" => "foo" }, "po" => [] }
         ]
        )
    def test_load(data)
      ENV["DESC"] = "bar\n    baz"
      yaml, hash = data
      file = create_tempfile(yaml)
      assert_equal(PipeFitter::YamlLoader.new.load(file.path), hash)
    end
  end

  sub_test_case "include_template" do
    def test_include_template()
      t1_str = %(foo: <%= context[:foo] %>)
      t1_yml = create_tempfile(t1_str)
      dp_str = %(<%= include_template("#{File.basename(t1_yml.path)}", indent:0, foo: 5) %>)
      dp_yml = create_tempfile(dp_str)
      assert_equal(PipeFitter::YamlLoader.new.load(dp_yml.path), {"foo" => 5})
    end
  end
end
