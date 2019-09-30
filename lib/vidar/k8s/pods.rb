module Vidar
  module K8s
    class Pods
      def initialize(namespace:, filter: nil)
        @namespace = namespace
        @filter = filter
      end

      def all_ready?
        if items.empty?
          Log.error "Could not fetch pod list"
          return false
        end

        Log.line

        container_statuses.each(&:print)

        Log.line

        container_statuses.all?(&:ok?)
      end

      private

      attr_reader :namespace, :filter

      def items
        @items ||= begin
          json = JSON.parse(kubectl_get.strip)
          json["items"] || []
        end
      end

      def kubectl_get
        if namespace == "all"
          `kubectl get pods --all-namespaces -o json`
        else
          `kubectl get pods -n #{namespace} -o json`
        end
      end

      def container_statuses
        return all_container_statuses unless filter

        all_container_statuses.select { |cs| cs.name == filter }
      end

      def all_container_statuses
        @all_container_statuses ||= container_statuses_data.map { |status| ContainerStatus.new(status) }
      end

      def container_statuses_data
        items.map do |i|
          namespace = i.dig("metadata", "namespace")
          statuses = i.dig("status", "containerStatuses") || []
          statuses.each { |s| s["namespace"] = namespace }
          statuses
        end.flatten
      end
    end
  end
end
