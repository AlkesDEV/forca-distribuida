module Api
  module V1
    class HealthController < ApplicationController
      def status
        redis_ok = begin
          REDIS.ping == "PONG"
        rescue StandardError
          false
        end

        render json: {
          status: "ok",
          server_id: ENV.fetch("SERVER_ID") { `hostname`.strip rescue "unknown" },
          redis: redis_ok ? "connected" : "unavailable",
          timestamp: Time.now.utc.iso8601
        }
      end
    end
  end
end
