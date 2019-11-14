module Vidar
  class Config
    DEFAULT_MANIFEST_FILE = "vidar.yml".freeze

    DEFAULT_OPTIONS = {
      compose_file:    -> { "docker-compose.ci.yml" },
      default_branch:  -> { "master" },
      current_branch:  -> { `git rev-parse --abbrev-ref HEAD`.strip.tr("/", "-") },
      revision:        -> { `git rev-parse HEAD`.strip },
      revision_name:   -> { `git show --pretty=format:"%s (%h)" -s HEAD`.strip },
      kubectl_context: -> { `kubectl config current-context`.strip },
      console_command: -> { "bin/console" },
    }.freeze

    class << self
      attr_reader :data
      attr_writer :manifest_file

      def load(file_path = manifest_file)
        @data = YAML.load_file(file_path)
        @loaded = true
      end

      def manifest_file
        @manifest_file || DEFAULT_MANIFEST_FILE
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
        load unless loaded?
        get(key) || fail(MissingConfigError, key)
      end

      def deploy_config
        deployments = get(:deployments) || {}

        return nil unless deployments.is_a?(Hash)

        deployment = deployments[get!(:kubectl_context)]

        return nil unless deployment

        deployment.transform_keys!(&:to_sym)
        deployment.transform_values! { |value| Vidar::Interpolation.call(value, self) }

        DeployConfig.new(deployment)
      end
    end
  end
end
