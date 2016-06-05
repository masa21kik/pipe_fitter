require_relative "helper"

class PipelineTest < Test::Unit::TestCase
  sub_test_case "load_yaml" do
    data("normal" => [
           "---\nname: foo\nunique_id: bar\ntags:\n- key: hoge\n  value: fuga\ndefinition:\n  pipeline_obects: []",
           { name: "foo", tags: [ { "key" => "hoge", "value" => "fuga" } ] }])
    def test_load_yaml(data)
      yml, expects = data
      file = create_tempfile(yml)
      p = PipeFitter::Pipeline.load_yaml(file.path)
      assert_equal(p.name, expects[:name])
      assert_equal(p.tags, expects[:tags])
    end

    data("normal" => [
           "---\npipeline_objects:\n- id: Default\n  name: Default\n  fields: []",
           "---\nname: foo\nunique_id: bar\ndefinition:\n  pipeline_objects:\n  - id: Default\n    name: Default\n    fields: []\n",
         ])
    def test_include_yaml(data)
      included_yml, expect = data
      included_file = create_tempfile(included_yml)
      base_yml = "---\nname: foo\nunique_id: bar\ndefinition: <%= include_yaml('#{included_file.path}') %>"
      base_file = create_tempfile(base_yml)
      p = PipeFitter::Pipeline.load_yaml(base_file.path)
      assert_equal(p.to_yaml, expect)
    end
  end

  sub_test_case "diff" do
    data("empty" => ["", ""],
         "same" => [
           "---\nname: foo\nunique_id: bar\ndefinition:\n  pipeline_obects: []",
           "---\nname: foo\nunique_id: bar\ndefinition:\n  pipeline_obects: []",
         ],
         "env variable" => [
           "---\nname: foo\nunique_id: bar\ndefinition:\n  pipeline_obects: []",
           "---\nname: <%= ENV['NAME'] %>\nunique_id: bar\ndefinition:\n  pipeline_obects: []",
         ],
         "swaped" => [
           <<-EOS,
---
name: foo
description: bar
tags:
- key: env
  value: staging
unique_id: baz
definition:
  pipeline_objects:
  - id: Default
    name: Default
    fields:
    - key: failureAndRerunMode
      string_value: CASCADE
    - key: schedule
      ref_value: ScheduleId_DefaultSchedule
  - id: ScheduleId_DefaultSchedule
    name: DefaultSchedule
    fields: []
         EOS
           <<-EOS,
---
name: foo
description: bar
tags:
- key: env
  value: staging
unique_id: baz
definition:
  pipeline_objects:
  - id: ScheduleId_DefaultSchedule
    name: DefaultSchedule
    fields: []
  - fields:
    - key: schedule
      ref_value: ScheduleId_DefaultSchedule
    - key: failureAndRerunMode
      string_value: CASCADE
    name: Default
    id: Default
         EOS
         ]
        )
    def test_no_diff(data)
      ENV["NAME"] = "foo"
      f1, f2 = data.map { |d| create_tempfile(d) }
      p1 = PipeFitter::Pipeline.load_yaml(f1.path)
      p2 = PipeFitter::Pipeline.load_yaml(f2.path)
      assert_equal(p1.diff(p2), "")
    end

    data("simple" => [
           ["---\nname: foo\nunique_id: bar1\ndefinition:\n  pipeline_obects: []",
            "---\nname: foo\nunique_id: bar2\ndefinition:\n  pipeline_obects: []"],
           "-unique_id: bar1\n+unique_id: bar2",
         ])
    def test_diff(data)
      files, expect = data
      f1, f2 = files.map { |d| create_tempfile(d) }
      p1 = PipeFitter::Pipeline.load_yaml(f1.path)
      p2 = PipeFitter::Pipeline.load_yaml(f2.path)
      assert_true(p1.diff(p2, :text).include?(expect))
    end
  end
end
