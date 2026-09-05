# The bank operations analyst: the model, the tools, and the instructions
# that turn a RubyLLM chat into a workspace that composes Poetry UI.
class Analyst
  MODEL = ENV.fetch("POETRY_IN_MOTION_MODEL", "anthropic/claude-opus-5")
  PROVIDER = "openrouter".freeze
  # A surface with table rows and chart data is a long tool call.
  MAX_OUTPUT_TOKENS = 16_000
  DATA_TOOLS = [ BankOverviewTool, SearchCustomersTool, CustomerProfileTool, TransactionsTool,
                 AggregateTool, LoansTool, MerchantsTool, BranchesTool ].freeze
  UI_TOOLS = [ RenderSurfaceTool, UpdateSurfaceTool, RemoveSurfaceTool ].freeze
  INSTRUCTIONS = Rails.root.join("app/prompts/analyst/instructions.txt.erb")

  # A new workspace bound to the configured model.
  def self.start(title: nil)
    Chat.create!(model: MODEL, provider: PROVIDER, assume_model_exists: true, title: title)
  end

  # Tools, instructions, and headers live in memory on the RubyLLM chat, so
  # every job re-applies them after loading the record.
  def self.prepare(chat)
    chat.assume_model_exists = true
    chat.with_tools(*tools_for(chat))
    chat.with_runtime_instructions(instructions)
    chat.with_headers("HTTP-Referer" => "https://poetryui.com", "X-Title" => "Poetry in Motion")
    chat.with_params(max_tokens: MAX_OUTPUT_TOKENS)
    chat
  end

  def self.tools_for(chat)
    (DATA_TOOLS + UI_TOOLS).map { |tool| tool.new(chat) }
  end

  def self.instructions
    ERB.new(INSTRUCTIONS.read, trim_mode: "-").result_with_hash(
      vocabulary: Workspace::Vocabulary.prompt,
      data_end: ApplicationTool::DATA_END.to_date.iso8601
    )
  end

  def self.configured?
    RubyLLM.config.openrouter_api_key.present?
  end
end
