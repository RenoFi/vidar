module Vidar
  module K8s
    class PodSet
      def initialize(namespace:, filter: nil)
        @namespace = namespace
        @filter = filter
      end

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

      def success?
        return false if containers.empty?

        containers.all?(&:success?)
      end

      def containers
        return all_containers unless filter

        all_containers.select { |cs| cs.name.to_s.include?(filter) }
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

      def ready_and_running_containers
        containers.select(&:ready_and_running?)
      end

      def all_containers
        @all_containers ||= containers_data.map { |status| Container.new(status) }
      end

      def containers_data
        items.map do |i|
          require 'ap'
          owner_references = i.dig("metadata", "ownerReferences") || []
          kind             = (owner_references[0] || {})["kind"]
          namespace        = i.dig("metadata", "namespace")
          statuses         = i.dig("status", "containerStatuses") || []
          statuses.each do |s|
            s["namespace"] = namespace
            s["kind"]      = kind
            s["pod_name"]  = i.dig("metadata", "name")
          end
          statuses
        end.flatten
      end
    end
  end
end
