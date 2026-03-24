module Vidar
  module K8s
    # Represents a collection of Kubernetes pods and their containers
    # fetched via `kubectl get pods` for a given namespace.
    class PodSet
      # @param namespace [String] Kubernetes namespace, or "all" for all namespaces
      # @param filter [String, nil] optional substring filter on container names
      def initialize(namespace:, filter: nil)
        @namespace = namespace
        @filter = filter
      end

      # @return [Boolean] true if any containers exist in the pod set
      def any?
        containers.any?
      end

      # @return [Boolean] true if any containers are in waiting state
      def waiting?
        containers.any?(&:waiting?)
      end

      # Logs current container states and returns whether all are deployed.
      # @return [Boolean]
      def deployed?
        if items.empty?
          Log.error "Could not fetch pod list"
          return false
        end

        Log.line

        containers.each(&:print)

        Log.line

        containers.all?(&:deployed?)
      end

      # @return [Boolean] true if all containers report success
      def success?
        return false if containers.empty?

        containers.all?(&:success?)
      end

      # @return [Array<Container>] filtered container list
      def containers
        if filter
          all_containers.select { |cs| cs.name.to_s.include?(filter) }
        else
          all_containers.reject(&:job?)
        end
      end

      private

      attr_reader :namespace, :filter

      def items
        @items ||= begin
          output = kubectl_get.strip
          return [] if output.empty?

          JSON.parse(output)["items"] || []
        rescue JSON::ParserError => e
          Log.error "Failed to parse kubectl JSON output: #{e.message}"
          []
        end
      end

      def kubectl_get
        envs = Run.kubectl_envs_hash
        stdout, stderr, status = if namespace == "all"
          Open3.capture3(envs, "kubectl", "get", "pods", "--all-namespaces", "-o", "json")
        else
          Open3.capture3(envs, "kubectl", "get", "pods", "-n", namespace, "-o", "json")
        end

        unless status.success?
          Log.error "kubectl get pods failed: #{stderr.strip}"
          return ""
        end

        stdout
      end

      def all_containers
        @all_containers ||= containers_data.map { |status| Container.new(status) }
      end

      def containers_data
        items.map do |i|
          owner_references = i.dig("metadata", "ownerReferences") || []
          kind = (owner_references[0] || {})["kind"]
          namespace = i.dig("metadata", "namespace")
          statuses = i.dig("status", "containerStatuses") || i.dig("status", "conditions") || []
          statuses.each do |s|
            s["namespace"] = namespace
            s["kind"] = kind
            s["pod_name"] = i.dig("metadata", "name")
          end
          statuses
        end.flatten
      end
    end
  end
end
