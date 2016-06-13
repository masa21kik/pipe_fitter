require_relative "helper"

class DataPipelineClientTest < Test::Unit::TestCase
  setup do
    @dpc = PipeFitter::DataPipelineClient.new(region: "ap-northeast-1")
    @yml = create_tempfile("---\npipeline_description:\n  name: foo\n  tags:\n  - key: bar\n    value: baz\npipeline_obects: []")
    @pl = PipeFitter::Pipeline.load_yaml(@yml.path)
    stub(@dpc).exec do
      Hashie::Mash.new(
        pipeline_id: "hoge",
        pipeline_description_list: [
          { tags: [{ key: "bar", value: "baz2" }], fields: [{ key: "uniqueId", string_value: "fuga" }] },
        ]
      )
    end
  end

  def test_create
    id, _res = @dpc.create(@pl)
    assert_equal(id, "hoge")
  end

  def test_register
    id, _res = @dpc.register(@yml.path)
    assert_equal(id, "hoge")
  end

  def test_update
    res = @dpc.update("hoge", @yml.path)
    assert_equal(res["pipeline_id"], "hoge")
  end

  def test_diff
    df = @dpc.diff("hoge", @yml.path, :text)
    assert_false(df.empty?)
  end

  def test_activate
    assert_nothing_raised { @dpc.activate("hoge", nil, nil) }
  end

  def test_sdk_opts
    assert_equal(@dpc.send(:sdk_opts), { region: "ap-northeast-1" })
  end
end
