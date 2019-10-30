module Vidar
  class CLI < Thor
    include Thor::Shell

    def self.exit_on_failure?
      true
    end

    desc "exec", "Run any given command in given docker-compose target, default is 'runner'"
    option :command
    option :target, default: "runner"
    def exec
      Run.docker_compose("run runner #{options[:command]}") || exit(1)
    end

    desc "pull", "Pull existing docker images to leverage docker caching"
    def pull
      Log.info "Pulling #{Config.get!(:image)} tags"
      Run.docker "pull #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)} 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:runner-#{Config.get!(:default_branch)} 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:release 2> /dev/null || true"
      Log.info "Docker images:"
      Run.docker("images")
    end

    desc "build", "Builds docker stages"
    def build
      Log.info "Building #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)}"
      Run.docker_compose "build runner"

      Log.info "Building #{Config.get!(:image)}:release"
      Run.docker_compose "build release"
    end

    desc "cache", "Caches intermediate docker stages"
    def cache
      Log.info "Publish #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)}"
      Run.docker "push #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)}"
    end

    desc "publish", "Publish docker images on docker registry"
    def publish
      Log.info "Publish #{Config.get!(:image)}:#{Config.get!(:revision)}"
      Run.docker "tag #{Config.get!(:image)}:release #{Config.get!(:image)}:#{Config.get!(:revision)}"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:revision)}"

      return unless Config.get!(:current_branch) == Config.get!(:default_branch)

      Log.info "Publish #{Config.get!(:image)}:latest"
      Run.docker "tag #{Config.get!(:image)}:release #{Config.get!(:image)}:latest"
      Run.docker "push #{Config.get!(:image)}:release"
      Run.docker "push #{Config.get!(:image)}:latest"
    end

    desc "deploy", "Perform k8s deployment with deploy hook"
    method_option :revision, required: false
    def deploy
      revision = options[:revision] || Config.get!(:revision)
      Log.info "Current kubectl context: #{Config.get!(:kubectl_context)} ###"

      Log.info "Looking for deploy hook..."
      template_name, error, status = Open3.capture3 "kubectl get cronjob deploy-hook-template -n #{Config.get!(:namespace)} -o name --ignore-not-found=true"

      if status.success?
        if template_name.to_s.empty?
          Log.info "No deploy hook found"
        else
          Log.info "Executing deploy hook #{template_name.strip!}..."
          Run.kubectl "delete job deploy-hook --ignore-not-found=true"
          Run.kubectl "set image cronjobs/deploy-hook-template deploy-hook-template=#{Config.get!(:image)}:#{revision} --all"
          Run.kubectl "create job deploy-hook --from=#{template_name}"

          deploy_status = Vidar::DeployStatus.new(namespace: Config.get!(:namespace), filter: "deploy-hook")
          deploy_status.wait_until_completed

          unless deploy_status.success?
            Run.kubectl "describe job deploy-hook"
            Log.error "Error running deploy hook template"
            exit(1)
          end
        end
      else
        Log.info "Error getting deploy hook template: #{error}"
        exit(1)
      end

      Log.info "Set kubectl image..."
      Run.kubectl "set image deployments,cronjobs *=#{Config.get!(:image)}:#{revision} --all"
    end

    desc "release", "Build and publish docker images"
    def release
      Log.info "Release #{options[:image]}:#{options[:revision]}"
      pull
      build
      cache
      publish
    end

    desc "monitor_deploy_status", "Check is deployment has finished and sends post-deploy notification"
    def monitor_deploy_status
      Log.info "Current kubectl context: #{Config.get!(:kubectl_context)} ###"
      Log.info "Checking if all containers in #{Config.get!(:namespace)} namespace(s) are ready..."

      deploy_config = Config.deploy_config

      Log.error "ERROR: could not find deployment config for #{Config.get!(:kubectl_context)} context" unless deploy_config

      slack_notification = SlackNotification.new(
        github:        Config.get!(:github),
        revision:      Config.get!(:revision),
        revision_name: Config.get!(:revision_name),
        deploy_config: deploy_config
      )

      sentry_notification = SentryNotification.new(
        revision:      Config.get!(:revision),
        deploy_config: deploy_config
      )

      deploy_status = Vidar::DeployStatus.new(namespace: Config.get!(:namespace))

      deploy_status.wait_until_completed

      if deploy_status.success?
        Log.info "OK: All containers are ready"
        slack_notification.success if slack_notification.configured?
        sentry_notification.call if sentry_notification.configured?
      else
        Log.error "ERROR: Some of containers are errored or not ready"
        slack_notification.failure if slack_notification.configured?
        exit(1)
      end
    end
  end
end
