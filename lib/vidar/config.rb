module Vidar
  class Config
    DEFAULT_MANIFEST_FILE = "vidar.yml".freeze

    DEFAULT_OPTIONS = {
      compose_file:   -> { "docker-compose.ci.yml" },
      default_branch: -> { "master" },
      current_branch: -> { `git rev-parse --abbrev-ref HEAD`.strip.tr("/", "-") },
      revision:       -> { `git rev-parse HEAD`.strip },
      revision_name:  -> { `git show --pretty=format:"%s (%h)" -s HEAD`.strip },
      cluster:        -> { `kubectl config current-context`.strip.split("_", 4)[-1] } # TODO improve context cleanup
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
        @data[key.to_s] || DEFAULT_OPTIONS[key.to_sym]&.call || fail(MissingConfigError, key)
      end
    end
  end
end
