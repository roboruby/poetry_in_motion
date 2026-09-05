require "test_helper"

class RubyLLMStreamGuardTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:env)

  test "a tool call cut off by the output limit raises a typed error with the reason" do
    accumulator = RubyLLM::StreamAccumulator.new
    accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, model_id: "m",
                                       tool_calls: { "call_1" => RubyLLM::ToolCall.new(id: "call_1", name: "render_surface", arguments: '{"surface_id":"x"') }))
    env = { RubyLLMFinishReasonGuard::FINISH_KEY => "length" }
    error = assert_raises(Workspace::StreamCutOff) { accumulator.to_message(FakeResponse.new(env)) }
    assert error.output_limit?
    assert_equal "render_surface", error.tool_name
    assert_match(/cut off after 17 bytes/, error.message)
    assert_kind_of RubyLLM::Error, error
  end

  test "a stream that simply ends mid call still raises the typed error" do
    accumulator = RubyLLM::StreamAccumulator.new
    accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, model_id: "m",
                                       tool_calls: { "c" => RubyLLM::ToolCall.new(id: "c", name: "update_surface", arguments: "{") }))
    error = assert_raises(Workspace::StreamCutOff) { accumulator.to_message(nil) }
    assert_not error.output_limit?
    assert_match(/stream ended early/, error.message)
  end

  test "a provider error chunk raises before the stream is consumed" do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
    env = {}
    chunk = %(data: {"choices":[{"index":0,"delta":{},"finish_reason":"error","error":{"message":"upstream overloaded","code":529}}]}\n\n)
    error = assert_raises(RubyLLM::ServerError) do
      provider.send(:process_stream_chunk, chunk, EventStreamParser::Parser.new, env) { |_chunk| }
    end
    assert_match(/upstream overloaded/, error.message)
    assert_equal "error", env[RubyLLMFinishReasonGuard::FINISH_KEY]
  end

  test "a length finish is recorded without raising" do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
    env = {}
    chunk = %(data: {"choices":[{"index":0,"delta":{"content":""},"finish_reason":"length"}]}\n\n)
    provider.send(:process_stream_chunk, chunk, EventStreamParser::Parser.new, env) { |_chunk| }
    assert_equal "length", env[RubyLLMFinishReasonGuard::FINISH_KEY]
  end
end
