module Vidar
  class HoneycombNotification
    def self.get
      new(
        github:        Config.get!(:github),
        revision:      Config.get!(:revision),
        revision_name: Config.get!(:revision_name),
        build_url:     Config.build_url,
        deploy_config: Config.deploy_config,
        api_key: Config.get(:honeycomb_api_key),
      )
    end

    def initialize(github:, revision:, revision_name:, deploy_config:, build_url: nil, api_key: nil, connection: Faraday.new)
      @github = github
      @revision = revision
      @revision_name = revision_name
      @build_url = build_url
      @api_key = api_key
      @dataset = deploy_config.honeycomb_dataset
      @connection = connection
      @start_time = Time.now.utc
      @end_time = nil
      @success = false
    end

    def configured?
      !dataset.nil? && !api_key.nil?
    end

    def success
      @end_time = Time.now.utc
      @success = true

      call
    end

    def failure
      @end_time = Time.now.utc
      @success = false

      call
    end

    private

    attr_reader :connection,
      :github,
      :revision,
      :revision_name,
      :dataset,
      :build_url,
      :api_key,
      :start_time,
      :end_time

    def success?
      @success
    end

    def call
      create_legacy_marker
      create_marker
    end

    def create_legacy_marker
      return false unless configured?

      response = connection.post do |req|
        req.url "https://api.honeycomb.io/1/markers/#{dataset}"
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Honeycomb-Team'] = api_key.to_s
        req.body = data.to_json
      end

      return true if response.status == 201

      warn "Honeycomb marker not created: status: #{response.status} response: #{response.body}"
      false
    end

    def create_marker
      return false unless dataset && Config.honeycomb_env_api_key(dataset)

      response = connection.post do |req|
        req.url "https://api.honeycomb.io/1/markers/__all__"
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Honeycomb-Team'] = Config.honeycomb_env_api_key(dataset).to_s
        req.body = data.to_json
      end

      return true if response.status == 201

      warn "Honeycomb marker not created: status: #{response.status} response: #{response.body}"
      false
    end

    def data
      {
        message: "#{success? ? 'Successful' : 'Failed'} deploy of #{github} revision #{revision} - #{revision_name}",
        type: success? ? "deploy" : "failed_deploy",
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        url: build_url,
      }
    end
  end
end
