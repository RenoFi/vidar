module Vidar
  class CLI < Thor
    include Thor::Shell

    def self.exit_on_failure?
      true
    end

    desc "exec", "Run any command in given docker-compose target, default target is `base`"
    option :command
    option :target, required: false
    def exec
      target = options[:target] || Config.get!(:base_stage_name)
      Run.docker_compose("run #{target} #{options[:command]}") || exit(1)
    end

    desc "pull", "Pull existing docker images to leverage docker caching"
    def pull
      Log.info "Pulling #{Config.get!(:image)} tags"
      Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:current_branch)} 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:default_branch)} 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:base_stage_name)} 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:release_stage_name)} 2> /dev/null || true"
      Log.info "Docker images:"
      Run.docker("images")
    end

    desc "build", "Build docker stages"
    def build
      Log.info "Building #{Config.get!(:base_stage_name)} image"
      Run.docker_compose "build #{Config.get!(:base_stage_name)}"

      Log.info "Building #{Config.get!(:release_stage_name)} image"
      Run.docker_compose "build #{Config.get!(:release_stage_name)}"
    end

    desc "cache", "Caches intermediate docker stages"
    def cache
      Log.info "Publishing #{Config.get!(:base_stage_name)} image"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:current_branch)}"
    end

    desc "publish", "Publish docker images on docker registry"
    def publish
      base_image_tag = "#{Config.get!(:image)}:#{Config.get!(:base_stage_name)}"
      revision_image_tag = "#{Config.get!(:image)}:#{Config.get!(:revision)}"
      release_image_tag = "#{Config.get!(:image)}:#{Config.get!(:release_stage_name)}"
      latest_image_tag = "#{Config.get!(:image)}:latest"

      Log.info "Publishing #{revision_image_tag}"
      Run.docker "tag #{release_image_tag} #{revision_image_tag}"
      Run.docker "push #{revision_image_tag}"

      return unless Config.default_branch?

      Log.info "Publishing #{base_image_tag}"
      Run.docker "tag #{base_image_tag}-#{Config.get!(:current_branch)} #{base_image_tag}"
      Run.docker "push #{base_image_tag}"

      Log.info "Publishing #{release_image_tag}"
      Run.docker "tag #{release_image_tag} #{latest_image_tag}"
      Run.docker "push #{release_image_tag}"
      Run.docker "push #{latest_image_tag}"
    end

    desc "deploy", "Perform k8s deployment with deploy hook"
    method_option :revision, required: false
    method_option :kubectl_context, required: false
    def deploy
      revision = options[:revision] || Config.get!(:revision)
      kubectl_context = options[:kubectl_context] || Config.get!(:kubectl_context)
      Log.info "Current kubectl context: #{kubectl_context}"

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
          deploy_status.wait_until_up
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

      slack_notification = SlackNotification.new(
        github:        Config.get!(:github),
        revision:      Config.get!(:revision),
        revision_name: Config.get!(:revision_name),
        build_url:     Config.build_url,
        deploy_config: Config.deploy_config
      )

      deploy_status = Vidar::DeployStatus.new(namespace: Config.get!(:namespace))

      deploy_status.wait_until_completed

      if deploy_status.success?
        Log.info "OK: All containers are ready"
        slack_notification.success if slack_notification.configured?
        invoke :notify_sentry
      else
        Log.error "ERROR: Some of containers are errored or not ready"
        slack_notification.failure if slack_notification.configured?
        exit(1)
      end
    end

    desc "kube_exec", "Execute given command in the first running pod"
    method_option :command
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
        container = containers.detect { |c| c.name == 'console' } || containers.last

        Log.info "Running #{options[:command]} in #{container.pod_name}"
        Run.kubectl("exec -it #{container.pod_name} -- #{options[:command]}")
      end
    end

    desc "console", "Execute console command in the first running pod"
    method_option :command, required: false
    method_option :name, required: false
    def console
      invoke :kube_exec, [], name: options[:name], command: options[:command] || Config.get!(:console_command)
    end

    desc "ssh", "Execute shell command in the first running pod"
    method_option :command, required: false
    method_option :name, required: false
    def ssh
      invoke :kube_exec, [], name: options[:name], command: options[:command] || Config.get!(:shell_command)
    end

    method_option :revision, required: false
    desc "notify_sentry", "Notify sentry about current release"
    def notify_sentry
      sentry_notification = SentryNotification.new(
        revision:      Config.get!(:revision),
        deploy_config: Config.deploy_config
      )

      sentry_notification.call if sentry_notification.configured?
    end

    method_option :message, required: true
    desc "notify_slack", "Send custom slack notification"
    def notify_slack
      slack_notification = SlackNotification.new(
        github:        Config.get!(:github),
        revision:      Config.get!(:revision),
        revision_name: Config.get!(:revision_name),
        build_url:     Config.build_url,
        deploy_config: Config.deploy_config
      )

      slack_notification.deliver(message: options[:message]) if slack_notification.configured?
    end
  end
end
