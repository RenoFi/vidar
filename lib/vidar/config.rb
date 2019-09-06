module Vidar
  class Config
    DEFAULT_MANIFEST_FILE = "vidar.yml".freeze

    DEFAULT_OPTIONS = {
      compose_file:   -> { "docker-compose.ci.yml" },
      default_branch: -> { "master" },
      current_branch: -> { `git rev-parse --abbrev-ref HEAD`.strip.tr("/", "-") },
      revision:       -> { `git rev-parse HEAD`.strip },
      revision_name:  -> { `git show --pretty=format:"%s (%h)" -s HEAD`.strip },
      cluster_name:   -> {
        cluster_names = get(:cluster_names).to_s
        current_context = `kubectl config current-context`.strip

        if cluster_names.empty?
          current_context
        else
          names_in_context = current_context.scan(Regexp.new(cluster_names))
          names_in_context.flatten.first || current_context
        end
      }
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

      def cluster_name
        cluster_names = get(:cluster_names).to_s
        current_context = `kubectl config current-context`.strip

        return current_context if cluster_names.empty?

        names_in_context = current_context.scan(Regexp.new(cluster_names))
        names_in_context.flatten.first || current_context
      end

      def get(key)
        load unless loaded?
        value = @data[key.to_s] || DEFAULT_OPTIONS[key.to_sym]&.call
        Vidar::Interpolation.call(value, self)
      end

      def get!(key)
        load unless loaded?
        get(key) || fail(MissingConfigError, key)
      end
    end
  end
end
