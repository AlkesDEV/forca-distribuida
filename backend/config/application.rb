require_relative "boot"
require "rails"
require "action_controller/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module ForcaDistribuida
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true

    config.action_cable.disable_request_forgery_protection = true

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "*",
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ["Authorization"]
      end
    end

    config.autoload_paths += %W[#{config.root}/app/services]
  end
end
