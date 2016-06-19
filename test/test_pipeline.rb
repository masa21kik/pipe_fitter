require_relative "helper"

class PipelineTest < Test::Unit::TestCase
  sub_test_case "diff" do
    data("empty" => ["", ""],
         "same" => [
           "---\npipeline_description:\n  name: foo\n  uniqueId: bar\npipeline_objects: []",
           "---\npipeline_description:\n  name: foo\n  uniqueId: bar\npipeline_objects: []",
         ],
         "env variable" => [
           "---\npipeline_description:\n  name: foo\n  uniqueId: bar\npipeline_objects: []",
           "---\npipeline_description:\n  name: <%= ENV['NAME'] %>\n  uniqueId: bar\npipeline_objects: []",
         ],
         "swaped" => [
           <<-EOS,
---
pipeline_description:
  name: foo
  description: bar
  tags:
  - key: env
    value: staging
  uniqueId: baz
pipeline_objects:
- id: Default
  name: Default
  failureAndRerunMode: CASCADE
  schedule:
    ref: ScheduleId_DefaultSchedule
- id: ScheduleId_DefaultSchedule
  name: DefaultSchedule
parameter_objects:
- id: myParam1
  description: param1
  type: String
- id: myParam2
  description: param2
  type: String
parameter_values:
- myParam1: hoge
- myParam2: fuga
           EOS
           <<-EOS,
---
pipeline_description:
  description: bar
  tags:
  - key: env
    value: staging
  uniqueId: baz
  name: foo
pipeline_objects:
- id: ScheduleId_DefaultSchedule
  name: DefaultSchedule
- schedule:
    ref: ScheduleId_DefaultSchedule
  failureAndRerunMode: CASCADE
  name: Default
  id: Default
parameter_objects:
- id: myParam2
  description: param2
  type: String
- id: myParam1
  type: String
  description: param1
parameter_values:
- myParam2: fuga
- myParam1: hoge
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
           ["---\npipeline_description:\n  name: foo\n  uniqueId: bar1\npipeline_obects: []",
            "---\npipeline_description:\n  name: foo\n  uniqueId: bar2\npipeline_obects: []"],
           "-  uniqueId: bar1\n+  uniqueId: bar2",
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
