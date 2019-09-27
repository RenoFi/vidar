module Vidar
  module K8s
    class Pods
      def initialize(namespace)
        @namespace = namespace
      end

      def all_ready?
        if items.empty?
          Log.error "Could not fetch pod list"
          return false
        end

        container_statuses.each do |container_status|
          container_status.print
        end

        Log.info "-", "-"

        container_statuses.all?(&:ok?)
      end

      private

      attr_reader :namespace

      def items
        @items ||= begin
          json = JSON.parse(kubectl_get.strip)
          json["items"] || []
        end
      end

      def kubectl_get
        if namespace == 'all'
          `kubectl get pods --all-namespaces -o json`
        else
          `kubectl get pods -n #{namespace} -o json`
        end
      end

      def container_statuses
        @container_statuses ||= items.map { |i| i.dig("status", "containerStatuses") }.flatten.compact.map { |status| ContainerStatus.new(status) }
      end
    end
  end
end
