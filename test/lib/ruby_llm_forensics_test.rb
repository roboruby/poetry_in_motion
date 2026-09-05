require "test_helper"
require "minitest/mock"

class RubyLLMForensicsTest < ActiveSupport::TestCase
  test "unparsable streamed tool arguments are logged, then raised" do
    accumulator = RubyLLM::StreamAccumulator.new
    accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, model_id: "m",
                                       tool_calls: { "call_1" => RubyLLM::ToolCall.new(id: "call_1", name: "render_surface", arguments: '{"surface_id":"x"') }))
    output = StringIO.new
    RubyLLM.stub(:logger, Logger.new(output)) do
      assert_raises(JSON::ParserError) { accumulator.to_message(nil) }
    end
    assert_match(/render_surface.*unparsable arguments/, output.string)
  end
end
