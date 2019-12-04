module Vidar
  class SlackNotification
    def initialize(github:, revision:, revision_name:, deploy_config:)
      @github          = github
      @revision        = revision
      @revision_name   = revision_name
      @deploy_name     = deploy_config.name
      @deploy_url      = deploy_config.url
      @default_color   = deploy_config.default_color
      @success_color   = deploy_config.success_color
      @failure_color   = deploy_config.failure_color
      @webhook_url     = deploy_config.slack_webhook_url
      @connection      = Faraday.new
    end

    def configured?
      !webhook_url.to_s.empty?
    end

    def failure
      message = "Failed deploy of #{github_link} to #{deploy_link} :fire: <!channel>"
      perform_with data(message: message, color: failure_color)
    end

    def success
      message = "Successful deploy of #{github_link} to #{deploy_link}"
      perform_with data(message: message, color: success_color)
    end

    def deliver(message:, color: default_color)
      perform_with data(message: message, color: color)
    end

    def perform_with(data)
      connection.post do |req|
        req.url webhook_url
        req.headers['Content-Type'] = 'application/json'
        req.body = data.to_json
      end
    end

    private

    attr_reader :github, :revision, :revision_name,
      :deploy_name, :deploy_url, :webhook_url,
      :default_color, :success_color, :failure_color,
      :connection

    def data(message:, color:)
      {
        "attachments": [
          {
            "title": github,
            "title_link": github_url,
            "color": color,
            "text": message,
            "fallback": message
          }
        ]
      }
    end

    def github_url
      "https://github.com/#{github}/commit/#{revision}"
    end

    def github_link
      "<#{github_url}|#{revision_name}>"
    end

    def deploy_link
      "<#{deploy_url}|#{deploy_name}>"
    end
  end
end
