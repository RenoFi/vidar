module Vidar
  class Run
    class << self
      def docker(command)
        system("docker #{command}") || exit(1)
      end

      def docker_compose(command)
        args = %w[revision current_branch].map { |arg| "#{arg.upcase}=#{Config.get!(arg.to_sym)}" }
        system("#{args.join(' ')} #{Config.get!(:compose_cmd)} -f #{Config.get!(:compose_file)} #{command}") || exit(1)
      end

      def kubectl(command, namespace: Config.get!(:namespace))
        parts = [kubectl_envs_string, "kubectl", "-n", namespace].compact + command.split
        system(parts.join(" ")) || exit(1)
      end

      def kubectl_capture3(command, namespace: Config.get!(:namespace))
        parts = [kubectl_envs_string, "kubectl", "-n", namespace].compact + command.split
        Open3.capture3(parts.join(" ")) || exit(1)
      end

      def kubectl_envs_string
        https_proxy = Config.deploy_config.https_proxy
        https_proxy ? "HTTPS_PROXY=#{https_proxy}" : nil
      end
    end
  end
end
