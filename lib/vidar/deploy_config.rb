module Vidar
  class DeployConfig
    SUCCESS_COLOR = "008800".freeze
    FAILURE_COLOR = "ff1100".freeze

    attr_reader :name, :url, :success_color, :failure_color, :slack_webhook_url

    def initialize(name:, url:, slack_webhook_url:, success_color: SUCCESS_COLOR, failure_color: FAILURE_COLOR)
      @name = name
      @url = url
      @success_color = success_color
      @failure_color = failure_color
      @slack_webhook_url = slack_webhook_url
    end
  end
end
