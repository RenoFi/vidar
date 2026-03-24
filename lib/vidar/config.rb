module Vidar
  # Loads and provides access to the vidar.yml manifest configuration.
  # Values fall back to DEFAULT_OPTIONS when not defined in the manifest.
  class Config
    DEFAULT_MANIFEST_FILE = "vidar.yml".freeze
    DEFAULT_BRANCHES = %w[main master].freeze
    REQUIRED_KEYS = %w[image namespace github].freeze

    DEFAULT_OPTIONS = {
      compose_file: -> { "docker-compose.ci.yml" },
      compose_cmd: -> { "docker compose" },
      default_branch: -> { (DEFAULT_BRANCHES & branches).first || DEFAULT_BRANCHES.first },
      current_branch: -> { (ENV["SEMAPHORE_GIT_WORKING_BRANCH"] || shell_capture("git rev-parse --abbrev-ref HEAD")).tr("/", "-") },
      revision: -> { shell_capture("git rev-parse HEAD") },
      revision_name: -> { shell_capture('git show --pretty=format:"%s (%h)" -s HEAD') },
      kubectl_context: -> { shell_capture("kubectl config current-context") },
      shell_command: -> { "/bin/sh" },
      console_command: -> { "bin/console" },
      base_stage_name: -> { "base" },
      release_stage_name: -> { "release" },
      honeycomb_api_key: -> { ENV["HONEYCOMB_API_KEY"] },
      sidecar_container_names: -> { ["istio-proxy"] }
    }.freeze

    class << self
      attr_reader :data
      attr_writer :manifest_file

      # Loads the manifest file and validates required keys.
      # @param file_path [String] path to vidar.yml
      # @raise [MissingManifestFileError] if the file does not exist
      # @raise [Error] if required keys are missing or schema is invalid
      def load(file_path = manifest_file)
        ensure_file_exist!(file_path)

        @data = YAML.load_file(file_path)
        validate_schema!
        @loaded = true
      end

      # @return [String] path to the manifest file
      def manifest_file
        @manifest_file || DEFAULT_MANIFEST_FILE
      end

      def ensure_file_exist!(file_path)
        fail(MissingManifestFileError, file_path) unless File.exist?(file_path)
      end

      # @return [Boolean] true if the manifest has been loaded
      def loaded?
        @loaded
      end

      # @param key [Symbol, String] config key
      # @return [Object, nil] value from manifest or default
      def get(key)
        load unless loaded?

        value = @data[key.to_s] || DEFAULT_OPTIONS[key.to_sym]&.call

        return value unless value.is_a?(String)

        Vidar::Interpolation.call(value, self)
      end

      # @param key [Symbol, String] config key
      # @return [Object] value from manifest or default
      # @raise [MissingConfigError] if the key is not found
      def get!(key)
        get(key) || fail(MissingConfigError, key)
      end

      # @return [String, nil] CI build URL resolved from env or manifest
      def build_url
        value = ENV[get(:build_env).to_s] || get(:build_url)
        value&.empty? ? nil : value
      end

      # @param env [String] environment name (maps to HONEYCOMB_API_KEY_<ENV>)
      # @return [String, nil] Honeycomb API key for the given environment
      def honeycomb_env_api_key(env)
        ENV["HONEYCOMB_API_KEY_#{env.upcase}"]
      end

      # @return [DeployConfig] deployment config for the current kubectl context
      def deploy_config
        deploy_configs[get!(:kubectl_context)] ||= build_deploy_config(get!(:kubectl_context))
      end

      def build_deploy_config(kubectl_context)
        deployments = get(:deployments)
        deployments = {} unless deployments.is_a?(Hash)
        deployment = deployments[kubectl_context]

        if deployment.nil?
          Log.error "ERROR: could not find deployment config for #{get!(:kubectl_context)} context"
          return nil
        end

        deployment.transform_keys!(&:to_sym)
        deployment.transform_values! { |value| Vidar::Interpolation.call(value, self) }

        DeployConfig.new(deployment)
      end

      def deploy_configs
        @deploy_configs ||= {}
      end

      # @return [Array<String>] local git branch names
      def branches
        stdout, _stderr, _status = Open3.capture3("git for-each-ref --format='%(refname:short)' refs/heads/*")
        stdout.split("\n")
      end

      # @return [Boolean] true if current branch is the default branch
      def default_branch?
        get!(:current_branch) == get!(:default_branch)
      end

      private

      def validate_schema!
        missing = REQUIRED_KEYS.reject { |k| @data.key?(k) }
        fail(Error, "vidar.yml is missing required keys: #{missing.join(", ")}") if missing.any?

        deployments = @data["deployments"]
        fail(Error, "vidar.yml: 'deployments' must be a Hash, got #{deployments.class}") if deployments && !deployments.is_a?(Hash)

        return unless deployments

        deployments.each do |context, config|
          fail(Error, "vidar.yml: deployment '#{context}' must be a Hash") unless config.is_a?(Hash)
          fail(Error, "vidar.yml: deployment '#{context}' is missing required key 'name'") unless config.key?("name")
        end
      end

      def shell_capture(command)
        stdout, _stderr, _status = Open3.capture3(command)
        stdout.strip
      end
    end
  end
end
