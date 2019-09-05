module Vidar
  class CLI < Thor
    include Thor::Shell

    desc "pull", "Pulls existing docker images to leverage docker caching"
    def pull
      log "Pulling #{Config.get(:image)} tags"
      docker_command("pull #{Config.get(:image)}:builder-#{Config.get(:current_branch)} 2> /dev/null || true")
      docker_command("pull #{Config.get(:image)}:builder 2> /dev/null || true")
      docker_command("pull #{Config.get(:image)}:release 2> /dev/null || true")
      log "Docker images:"
      puts docker_command("images")
    end

    desc "build", "Builds docker stages"
    def build
      log "Building #{Config.get(:image)}:builder-#{Config.get(:current_branch)}"
      docker_compose_command("build builder")

      log "Building #{Config.get(:image)}:runner-#{Config.get(:current_branch)}"
      docker_compose_command("build runner")

      log "Building #{Config.get(:image)}:release"
      docker_compose_command("build release")
    end

    desc "cache", "Caches intermediate docker stages"
    def cache
      log "Publish #{Config.get(:image)}:builder-#{Config.get(:current_branch)}"
      docker_command("push #{Config.get(:image)}:builder-#{Config.get(:current_branch)}")
    end

    desc "publish", "Publishes docker images on docker registry"
    def publish
      log "Publish #{Config.get(:image)}:#{Config.get(:revision)}"
      docker_command("tag #{Config.get(:image)}:release #{Config.get(:image)}:#{Config.get(:revision)}")
      docker_command("push #{Config.get(:image)}:#{Config.get(:revision)}")

      return unless Config.get(:current_branch) == Config.get(:default_branch)

      log "Publish #{Config.get(:image)}:builder"
      docker_command("tag #{Config.get(:image)}:builder-#{Config.get(:current_branch)} #{Config.get(:image)}:builder")
      docker_command("push #{Config.get(:image)}:builder")

      log "Publish #{Config.get(:image)}:latest"
      docker_command("tag #{Config.get(:image)}:release #{Config.get(:image)}:latest")
      docker_command("push #{Config.get(:image)}:release")
      docker_command("push #{Config.get(:image)}:latest")
    end

    private

    desc "log", "Prints out and colorize given text"
    def log(text)
      puts ColorizedString["### #{text} ".ljust(100, '#')].colorize(:green)
    end

    desc "docker_compose_command", "Runs docker-compose command with given command"
    def docker_compose_command(command)
      args = %w[revision current_branch].map { |arg| "#{arg.upcase}=#{Config.get(arg.to_sym)}" }
      system("#{args.join(' ')} docker-compose -f #{Config.get(:compose_file)} #{command}") || exit(1)
    end

    desc "run_docker", "Runs docker command with given command"
    def docker_command(command)
      system("docker #{command}") || exit(1)
    end
  end
end
