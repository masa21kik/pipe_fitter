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
end
