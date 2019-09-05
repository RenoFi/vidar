module Vidar
  class SlackNotification
    SUCCESS_COLOR = "good".freeze
    ERROR_COLOR = "danger".freeze

    def initialize(webhook_url:, github:, revision:, revision_name:, cluster:, cluster_url:)
      @webhook_url = webhook_url
      @github = github
      @revision = revision
      @cluster = cluster
      @cluster_url = cluster_url
    end

    def error
      message = "Failed deploy of #{github_link} to #{cluster_link} :fire: <!channel>"
      perform data(message: message, color: ERROR_COLOR)
    end

    def success
      message = "Successful deploy of #{github_link} to #{cluster_link}"
      perform data(message: message, color: SUCCESS_COLOR)
    end

    def perform(data)
      `curl -X POST -H "Content-type: application/json" --data '#{data}' '#{webhook_url}' 2>&1 /dev/null`
    end

    private

    attr_reader :webhook_url, :github, :revision, :revision_name, :cluster, :cluster_url

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
      }.to_json
    end

    def github_url
      "https://github.com/#{github}/commit/#{revision}"
    end

    def github_link
      "<#{github_url}|#{revision_name}>"
    end

    def cluster_link
      "<#{cluster_url}|#{cluster}>"
    end
  end
end
