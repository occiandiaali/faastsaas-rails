if Rails.env.development? || Rails.env.test?
  begin
    require "dotenv"
    Dotenv.load(File.expand_path("../../.env", __dir__))
  rescue LoadError
    Rails.logger.warn("dotenv is not available; skipping .env loading")
  end
end
