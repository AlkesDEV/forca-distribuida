require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_cable.disable_request_forgery_protection = true
  config.action_cable.url = ENV.fetch("ACTION_CABLE_URL", "ws://localhost:3000/cable")
  config.log_level = :debug
  config.log_tags = [:request_id]
  config.cache_store = :memory_store
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
end
