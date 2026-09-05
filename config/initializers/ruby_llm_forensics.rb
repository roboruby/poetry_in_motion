# A streamed tool call whose arguments do not parse (a cut-off stream, or
# fragments landing on the wrong call) raises JSON::ParserError deep inside
# RubyLLM with no trace of what arrived. This logs the raw arguments before
# the error propagates so the failure can be diagnosed from the log.
module RubyLLMToolCallForensics
  private

  def tool_calls_from_stream
    super
  rescue JSON::ParserError => error
    tool_calls.each_value do |tool_call|
      arguments = tool_call.arguments.to_s
      RubyLLM.logger.error(
        "RubyLLM streamed tool call #{tool_call.name.inspect} (#{tool_call.id}) has unparsable arguments " \
        "(#{arguments.bytesize} bytes, #{error.message}): head=#{arguments[0, 160].inspect} tail=#{arguments[-160..].inspect}"
      )
    end
    raise
  end
end

RubyLLM::StreamAccumulator.prepend(RubyLLMToolCallForensics)
