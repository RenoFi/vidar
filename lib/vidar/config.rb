module Vidar
  class Config
    DEFAULT_MANIFEST_FILE = "vidar.yml".freeze
    DEFAULT_BRANCHES = %w[main master].freeze

    DEFAULT_OPTIONS = {
      compose_file:       -> { "docker-compose.ci.yml" },
      default_branch:     -> { (DEFAULT_BRANCHES & branches).first || DEFAULT_BRANCHES.first },
      current_branch:     -> { `git rev-parse --abbrev-ref HEAD`.strip.tr("/", "-") },
      revision:           -> { `git rev-parse HEAD`.strip },
      revision_name:      -> { `git show --pretty=format:"%s (%h)" -s HEAD`.strip },
      kubectl_context:    -> { `kubectl config current-context`.strip },
      shell_command:      -> { "/bin/sh" },
      console_command:    -> { "bin/console" },
      base_stage_name:    -> { "base" },
      release_stage_name: -> { "release" },
      honeycomb_api_key:  -> { ENV['HONEYCOMB_API_KEY'] },
    }.freeze

    class << self
      attr_reader :data
      attr_writer :manifest_file

      def load(file_path = manifest_file)
        ensure_file_exist!(file_path)

        @data = YAML.load_file(file_path)
        @loaded = true
      end

      def manifest_file
        @manifest_file || DEFAULT_MANIFEST_FILE
      end

      def ensure_file_exist!(file_path)
        fail(MissingManifestFileError, file_path) unless File.exist?(file_path)
      end

      def loaded?
        @loaded
      end

      def get(key)
        load unless loaded?

        value = @data[key.to_s] || DEFAULT_OPTIONS[key.to_sym]&.call

        return value unless value.is_a?(String)

        Vidar::Interpolation.call(value, self)
      end

      def get!(key)
        get(key) || fail(MissingConfigError, key)
      end

      def build_url
        value = ENV[get(:build_env).to_s] || get(:build_url)
        value&.empty? ? nil : value
      end

      def honeycomb_env_api_key(env)
        ENV["HONEYCOMB_API_KEY_#{env.upcase}"]
      end

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

      def branches
        `git for-each-ref --format='%(refname:short)' refs/heads/*`.split("\n")
      end

      def default_branch?
        get!(:current_branch) == get!(:default_branch)
      end
    end
  end
end
