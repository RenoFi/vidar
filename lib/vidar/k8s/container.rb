module Vidar
  module K8s
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

      def name
        data["name"] || pod_name
      end

      def deployed?
        return terminated? if job?

        ready? && running?
      end

      def success?
        return terminated_completed? if job?

        ready_and_running?
      end

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
        "| #{parts.join(' | ')} |"
      end

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
          [ColorizedString[state.inspect].light_red, ""]
        end
      end

      def waiting?
        state["waiting"]
      end

      def ready?
        data["ready"]
      end

      def running?
        !running_started_at.nil?
      end

      def running_started_at
        state.dig("running", "startedAt")
      end

      def terminated?
        !state["terminated"].nil?
      end

      def terminated_completed?
        state.dig("terminated", "reason") == "Completed" || state.dig("terminated", "exitCode") == 0
      end

      def terminated_finished_at
        state.dig("terminated", "finishedAt")
      end

      def terminated_error?
        state.dig("terminated", "reason") == "Error" || state.dig("terminated", "exitCode")
      end

      def unschedulable?
        reason == "Unschedulable"
      end

      def job?
        kind == JOB_KIND
      end

      def istio?
        name == "istio-proxy"
      end
    end
  end
end
