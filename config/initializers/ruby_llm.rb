RubyLLM.configure do |config|
  # OPENROUTER_API_KEY comes from .env in development and test (dotenv) or the environment.
  # The test suite never reaches the network, but RubyLLM checks the key when
  # a chat is prepared, so tests run with a placeholder unless one is set.
  config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY") { Rails.env.test? ? "test-key" : nil }
  config.default_model = ENV.fetch("POETRY_IN_MOTION_MODEL", "anthropic/claude-opus-5")

  # OpenRouter forwards to many vendors; send instructions as a real system role.
  config.openai_use_system_role = true
  config.request_timeout = 180
  config.logger = Rails.logger

  # Use the association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
