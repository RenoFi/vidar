module Vidar
  class Run
    class << self
      def docker(command)
        system("docker #{command}") || exit(1)
      end

      def docker_compose
        args = %w[revision current_branch].map { |arg| "#{arg.upcase}=#{Config.get(arg.to_sym)}" }
        system("#{args.join(' ')} docker-compose -f #{Config.get(:compose_file)} #{command}") || exit(1)
      end

      def kubectl(command)
        system("kubectl --namespace=#{Config.get(:namespace)} #{command}") || exit(1)
      end
    end
  end
end
