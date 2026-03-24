module Vidar
  module K8s
    # Represents a single Kubernetes container and its current state.
    class Container
      JOB_KIND = "Job".freeze

      attr_reader :data, :state, :namespace,
        :kind, :pod_name,
        :reason, :message

      def initialize(data)
        @data = data
        @state = data["state"] || {}
        @namespace = data["namespace"]
        @kind = data["kind"]
        @pod_name = data["pod_name"]
        @reason = data["reason"]
        @message = data["message"]
      end

      # @return [String] container name, falling back to pod name
      def name
        data["name"] || pod_name
      end

      # @return [Boolean] true if the container is considered successfully deployed
      def deployed?
        return terminated? if job?

        ready? && running?
      end

      # @return [Boolean] true if the container completed successfully
      def success?
        return terminated_completed? if job?

        ready_and_running?
      end

      # @return [Boolean] true if the container is ready and running
      def ready_and_running?
        ready? && running?
      end

      def print
        puts to_text
      end

      def to_text
        parts = []
        parts << namespace.to_s.ljust(20, " ")
        parts << name.to_s.ljust(35, " ")
        parts += text_statuses.map { |s| s.ljust(45, " ") }
        "| #{parts.join(" | ")} |"
      end

      # @return [Array<String>] two-element array with status label and detail
      def text_statuses
        if unschedulable?
          [ColorizedString["Unschedulable"].light_red, ColorizedString[message].light_red]
        elsif running?
          if job?
            [ColorizedString["Running"].light_yellow, "Started at: #{running_started_at}"]
          elsif ready?
            [ColorizedString["Ready & Running"].light_green, "Started at: #{running_started_at}"]
          else
            [ColorizedString["Not ready"].light_red, "Started at: #{running_started_at}"]
          end
        elsif terminated_completed?
          [ColorizedString["Terminated/Completed"].light_green, terminated_finished_at ? "Finished at: #{terminated_finished_at}" : ""]
        elsif terminated_error?
          [ColorizedString["Terminated/Error"].light_red, ""]
        elsif waiting?
          [ColorizedString["Waiting"].light_yellow, ""]
        else
          [ColorizedString["Unknown"].light_yellow, state.empty? ? "" : state.inspect]
        end
      end

      # @return [Boolean] true if container state is "waiting"
      def waiting?
        state["waiting"]
      end

      # @return [Boolean] true if container is ready
      def ready?
        data["ready"]
      end

      # @return [Boolean] true if container is running
      def running?
        !running_started_at.nil?
      end

      def running_started_at
        state.dig("running", "startedAt")
      end

      # @return [Boolean] true if container has terminated (any reason)
      def terminated?
        !state["terminated"].nil?
      end

      # @return [Boolean] true if container terminated successfully
      def terminated_completed?
        state.dig("terminated", "reason") == "Completed" || state.dig("terminated", "exitCode") == 0
      end

      def terminated_finished_at
        state.dig("terminated", "finishedAt")
      end

      # @return [Boolean] true if container terminated with an error exit code
      def terminated_error?
        exit_code = state.dig("terminated", "exitCode")
        state.dig("terminated", "reason") == "Error" || (!exit_code.nil? && exit_code != 0)
      end

      # @return [Boolean] true if container state is unknown
      def unknown?
        !unschedulable? && !running? && !terminated? && !waiting?
      end

      # @return [Boolean] true if container reason is Unschedulable
      def unschedulable?
        reason == "Unschedulable"
      end

      # @return [Boolean] true if this container belongs to a Job
      def job?
        kind == JOB_KIND
      end

      # @param sidecar_names [Array<String>] list of sidecar container names to match
      # @return [Boolean] true if this container is a known sidecar
      def sidecar?(sidecar_names = ["istio-proxy"])
        sidecar_names.include?(name.to_s)
      end

      # @return [Boolean] true if this is an istio-proxy sidecar container
      def istio?
        name == "istio-proxy"
      end
    end
  end
end
