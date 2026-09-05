# OpenRouter reports what ended a streamed reply in the last chunk
# ("finish_reason": "stop", "tool_calls", "length", or "error", with the
# provider's error object inside the choice). RubyLLM ignores the field, so
# a reply that was cut off mid tool call surfaces only as a JSON parse error
# with nothing to say why. This records the reason on the request, raises at
# once for a provider error, and turns the parse failure into a typed error
# the job can retry.
module Workspace
  # A streamed tool call whose arguments never completed. `finish_reason`
  # says why when the provider said ("length", "error"); nil means the
  # stream simply ended.
  class StreamCutOff < RubyLLM::Error
    attr_reader :finish_reason, :tool_name, :bytes

    def initialize(response = nil, message = nil, finish_reason: nil, tool_name: nil, bytes: 0)
      super(response, message)
      @finish_reason = finish_reason
      @tool_name = tool_name
      @bytes = bytes
    end

    def output_limit?
      finish_reason == "length"
    end
  end
end

module RubyLLMFinishReasonGuard
  FINISH_KEY = :poetry_in_motion_finish_reason
  ERROR_KEY = :poetry_in_motion_stream_error

  private

  def process_stream_chunk(chunk, parser, env, &)
    if (finish = chunk[/"finish_reason"\s*:\s*"(length|error)"/, 1])
      env[FINISH_KEY] = finish
      env[ERROR_KEY] = chunk[/"error"\s*:\s*(\{.*?\})/m, 1]
      RubyLLM.logger.warn("RubyLLM stream finished with #{finish}: #{env[ERROR_KEY] || chunk[0, 300]}")
      raise RubyLLM::ServerError.new(nil, "the provider failed mid-stream: #{env[ERROR_KEY] || "no detail"}") if finish == "error"
    end
    super
  end
end

module RubyLLMToolCallCutOff
  def to_message(response)
    super
  rescue JSON::ParserError => error
    env = response.respond_to?(:env) ? response.env : nil
    finish = env && env[RubyLLMFinishReasonGuard::FINISH_KEY]
    broken = tool_calls.values.find { |tool_call| tool_call.arguments.is_a?(String) } || tool_calls.values.last
    bytes = broken&.arguments.to_s.bytesize
    reason = finish == "length" ? "the reply hit its output limit" : "the stream ended early (#{error.message})"
    raise Workspace::StreamCutOff.new(response, "tool call #{broken&.name.inspect} was cut off after #{bytes} bytes: #{reason}",
                                      finish_reason: finish, tool_name: broken&.name, bytes: bytes)
  end
end

RubyLLM::Provider.prepend(RubyLLMFinishReasonGuard)
RubyLLM::StreamAccumulator.prepend(RubyLLMToolCallCutOff)
