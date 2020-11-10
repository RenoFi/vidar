module Vidar
  class DeployConfig
    SUCCESS_COLOR = "008800".freeze
    FAILURE_COLOR = "ff1100".freeze
    DEFAULT_COLOR = "000000".freeze

    attr_reader :name, :url,
      :default_color, :success_color, :failure_color,
      :slack_webhook_url, :sentry_webhook_url

    def initialize(options)
      @name = options.fetch(:name)
      @url = options.fetch(:url, nil)

      @default_color = options.fetch(:default_color, DEFAULT_COLOR)
      @success_color = options.fetch(:success_color, SUCCESS_COLOR)
      @failure_color = options.fetch(:failure_color, FAILURE_COLOR)

      @slack_webhook_url = options[:slack_webhook_url]
      @sentry_webhook_url = options[:sentry_webhook_url]
    end
  end
end
