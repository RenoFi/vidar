module Vidar
  class SlackNotification
    SUCCESS_COLOR = "good".freeze
    ERROR_COLOR = "danger".freeze

    def initialize(webhook_url:, github:, revision:, revision_name:, cluster_name:, cluster_url:)
      @webhook_url   = webhook_url
      @github        = github
      @revision      = revision
      @revision_name = revision_name
      @cluster_name  = cluster_name
      @cluster_url   = cluster_url
      @connection    = Faraday.new
    end

    def configured?
      !webhook_url.to_s.empty?
    end

    def error
      message = "Failed deploy of #{github_link} to #{cluster_link} :fire: <!channel>"
      perform_with data(message: message, color: ERROR_COLOR)
    end

    def success
      message = "Successful deploy of #{github_link} to #{cluster_link}"
      perform_with data(message: message, color: SUCCESS_COLOR)
    end

    def perform_with(data)
      p data
      connection.post do |req|
        req.url webhook_url
        req.headers['Content-Type'] = 'application/json'
        req.body = data.to_json
      end
    end

    private

    attr_reader :webhook_url, :github, :revision, :revision_name, :cluster_name, :cluster_url, :connection

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

    def cluster_link
      "<#{cluster_url}|#{cluster_name}>"
    end
  end
end
