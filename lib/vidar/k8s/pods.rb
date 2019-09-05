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
          Log.info container_status.to_text
        end

        Log.info "-", "-"

        container_statuses.all?(&:ok?)
      end

      private

      attr_reader :pods, :namespace

      def items
        @items ||= begin
          output = `kubectl get pods -n #{Config.get(:namespace)} -o json`
          json = JSON.parse(output.strip)
          json["items"] || []
        end
      end

      def container_statuses
        @container_statuses ||= items.map { |i| i.dig("status", "containerStatuses") }.flatten.compact.map { |status| ContainerStatus.new(status) }
      end
    end
  end
end
