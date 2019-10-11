module Vidar
  class SentryNotification
    def initialize(revision:, deploy_config:)
      @revision = revision
      @webhook_url = deploy_config.sentry_webhook_url
      @connection = Faraday.new
    end

    def configured?
      !webhook_url.to_s.empty?
    end

    def call
      connection.post do |req|
        req.url webhook_url
        req.headers['Content-Type'] = 'application/json'
        req.body = data.to_json
      end
    end

    private

    attr_reader :connection, :revision, :webhook_url

    def data
      {
        "version": revision
      }
    end
  end
end
