module Vidar
  class SlackNotification
    def self.get
      new(
        github:        Config.get!(:github),
        revision:      Config.get!(:revision),
        revision_name: Config.get!(:revision_name),
        build_url:     Config.build_url,
        deploy_config: Config.deploy_config
      )
    end

    def initialize(github:, revision:, revision_name:, deploy_config:, build_url: nil, connection: Faraday.new)
      @github = github
      @revision = revision
      @revision_name = revision_name
      @build_url = build_url
      @deploy_name = deploy_config.name
      @deploy_url = deploy_config.url
      @default_color = deploy_config.default_color
      @success_color = deploy_config.success_color
      @failure_color = deploy_config.failure_color
      @webhook_url = deploy_config.slack_webhook_url
      @connection = connection
    end

    def configured?
      !webhook_url.to_s.empty?
    end

    def failure
      message = [
        "<!channel> Failed deploy of #{github_link} to #{deploy_link}.",
        build_link,
      ]
      perform_with data(message:, color: failure_color)
    end

    def success
      message = [
        "Successful deploy of #{github_link} to #{deploy_link}.",
        build_link,
      ]
      perform_with data(message:, color: success_color)
    end

    def deliver(message:, color: default_color)
      perform_with data(message:, color:)
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
      :connection, :build_url

    def data(message:, color:)
      text = [message].flatten.compact.join("\n")
      {
        attachments: [
          {
            title: github,
            title_link: github_url,
            color:,
            text:,
            fallback: text,
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
      return deploy_name unless deploy_url

      "<#{deploy_url}|#{deploy_name}>"
    end

    def build_link
      build_url && "<#{build_url}|View the build.>"
    end
  end
end
