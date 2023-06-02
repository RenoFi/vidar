module Vidar
  class Run
    class << self
      def docker(command)
        system("docker #{command}") || exit(1)
      end

      def docker_compose(command)
        args = %w[revision current_branch].map { |arg| "#{arg.upcase}=#{Config.get!(arg.to_sym)}" }
        system("#{args.join(' ')} docker-compose -f #{Config.get!(:compose_file)} #{command}") || exit(1)
      end

      def kubectl(command, namespace: Config.namespace)
        system("#{kubectl_envs_string}kubectl --namespace=#{namespace} #{command}") || exit(1)
      end

      def kubectl_envs_string
        https_proxy = Config.deploy_config.https_proxy
        "HTTPS_PROXY=#{https_proxy} " if https_proxy
      end
    end
  end
end
