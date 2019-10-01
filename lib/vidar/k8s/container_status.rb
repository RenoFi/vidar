module Vidar
  module K8s
    class ContainerStatus
      JOB_KIND = "Job".freeze

      attr_reader :data, :state, :namespace, :kind

      def initialize(data)
        @data      = data
        @state     = data["state"]
        @namespace = data["namespace"]
        @kind      = data["kind"]
      end

      def name
        data["name"]
      end

      def deployed?
        return terminated? if job?

        ready? && running?
      end

      def success?
        return terminated_completed? if job?

        ready? && running?
      end

      def print
        puts to_text
      end

      def to_text
        parts = []
        parts << namespace.to_s.ljust(20, " ")
        parts << name.to_s.ljust(25, " ")
        parts += text_statuses.map { |s| s.ljust(40, " ") }
        "| #{parts.join(' | ')} |"
      end

      def text_statuses
        if running?
          if ready?
            [ColorizedString["Ready & Running"].light_green, "Started at: #{running_started_at}"]
          else
            [ColorizedString["Not ready"].light_red, "Started at: #{running_started_at}"]
          end
        elsif terminated_completed?
          [ColorizedString["Terminated/Completed"].light_green, terminated_finished_at ? "Finished at: #{terminated_finished_at}" : ""]
        elsif terminated_error?
          [ColorizedString["Terminated/Error"].light_red, ""]
        elsif waiting?
          [ColorizedString["Waiting"].light_green, ""]
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

      def job?
        kind == JOB_KIND
      end
    end
  end
end
