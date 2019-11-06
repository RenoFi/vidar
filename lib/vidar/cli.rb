module Vidar
  class CLI < Thor
    include Thor::Shell

    def self.exit_on_failure?
      true
    end

    desc "exec", "Run any command in given docker-compose target, default target is `runner`"
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
      Run.docker "pull #{Config.get!(:image)}:runner 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:release 2> /dev/null || true"
      Log.info "Docker images:"
      Run.docker("images")
    end

    desc "build", "Build docker stages"
    def build
      Log.info "Building runner image"
      Run.docker_compose "build runner"

      Log.info "Building release image"
      Run.docker_compose "build release"
    end

    desc "cache", "Caches intermediate docker stages"
    def cache
      Log.info "Publishing runner image"
      Run.docker "push #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)}"
    end

    desc "publish", "Publish docker images on docker registry"
    def publish
      Log.info "Publishing #{Config.get!(:image)}:#{Config.get!(:revision)}"
      Run.docker "tag #{Config.get!(:image)}:release #{Config.get!(:image)}:#{Config.get!(:revision)}"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:revision)}"

      return unless Config.get!(:current_branch) == Config.get!(:default_branch)

      Log.info "Publishing #{Config.get!(:image)}:runner"
      Run.docker "tag #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)} #{Config.get!(:image)}:runner"
      Run.docker "push #{Config.get!(:image)}:runner"

      Log.info "Publishing #{Config.get!(:image)}:release"
      Run.docker "tag #{Config.get!(:image)}:release #{Config.get!(:image)}:latest"
      Run.docker "push #{Config.get!(:image)}:release"
      Run.docker "push #{Config.get!(:image)}:latest"
    end

    desc "deploy", "Perform k8s deployment with deploy hook"
    method_option :revision, required: false
    def deploy
      revision = options[:revision] || Config.get!(:revision)
      Log.info "Current kubectl context: #{Config.get!(:kubectl_context)}"

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
      Log.info "Build and release #{Config.get!(:image)}:#{Config.get!(:revision)}"
      pull
      build
      cache
      publish
    end

    desc "monitor_deploy_status", "Check is deployment has finished and sends post-deploy notification"
    def monitor_deploy_status
      Log.info "Current kubectl context: #{Config.get!(:kubectl_context)}"
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

    desc "kube_exec", "Execute given command in running pod"
    method_option :command, default: "/bin/sh"
    method_option :name, required: false
    def kube_exec
      Log.info "Current kubectl context: #{Config.get!(:kubectl_context)}"

      deploy_config = Config.deploy_config

      Log.error "ERROR: could not find deployment config for #{Config.get!(:kubectl_context)} context" unless deploy_config

      pod_set = K8s::PodSet.new(namespace: Config.get!(:namespace), filter: options[:name])
      containers = pod_set.containers.select(&:ready_and_running?).reject(&:istio?)

      if containers.empty?
        name = options[:name] || 'any'
        Log.error "No running containers found with *#{name}* name"
        exit(1)
      else
        Log.info "Available containers:"
        containers.each(&:print)
        container = containers.first

        Log.info "Running #{options[:command]} in #{container.pod_name}"
        Run.kubectl("exec -it #{container.pod_name} -- #{options[:command]}")
      end
    end
  end
end
