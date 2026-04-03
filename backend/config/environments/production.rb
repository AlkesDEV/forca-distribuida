require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_cable.disable_request_forgery_protection = true
  config.log_level = :info
  config.log_tags = [:request_id]
  config.force_ssl = false
end
