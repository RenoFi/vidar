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

    desc "version", "Prints current version"
    def version
      puts Vidar::VERSION
    end

    desc "pull", "Pull existing docker images to leverage docker caching"
    def pull
      Log.info "Pulling #{Config.get!(:image)} tags"
      if Config.default_branch?
        Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}} 2> /dev/null || true"
        Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:default_branch)} 2> /dev/null || true"
      else
        Run.docker "pull #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:current_branch)} 2> /dev/null || true"
      end
      Log.info "Docker images:"
      Run.docker("images")
    end

    desc "build_and_cache_base", "Build and caches base stage"
    def build_and_cache_base
      Log.info "Building #{Config.get!(:base_stage_name)} image"
      Run.docker_compose "build #{Config.get!(:base_stage_name)}"

      Log.info "Publishing #{Config.get!(:base_stage_name)} image"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:current_branch)}"
    end

    desc "build", "Build docker stages"
    option :target, required: false
    def build
      if options[:target]
        Log.info "Building #{options[:target]} image"
        Run.docker_compose "build #{options[:target]}"
      else
        Log.info "Building #{Config.get!(:base_stage_name)} image"
        Run.docker_compose "build #{Config.get!(:base_stage_name)}"

        Log.info "Building #{Config.get!(:release_stage_name)} image"
        Run.docker_compose "build #{Config.get!(:release_stage_name)}"
      end
    end

    desc "cache", "Caches intermediate docker stages"
    def cache
      Log.info "Publishing #{Config.get!(:base_stage_name)} image"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:current_branch)}"
    end

    desc "publish", "Publish docker images on docker registry"
    def publish
      revision_image_tag = "#{Config.get!(:image)}:#{Config.get!(:revision)}"
      release_image_tag = "#{Config.get!(:image)}:#{Config.get!(:release_stage_name)}"
      latest_image_tag = "#{Config.get!(:image)}:latest"

      Log.info "Publishing #{revision_image_tag}"
      Run.docker "tag #{release_image_tag} #{revision_image_tag}"
      Run.docker "push #{revision_image_tag}"

      return unless Config.default_branch?

      Log.info "Publishing #{Config.get!(:base_stage_name)} image"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:base_stage_name)}-#{Config.get!(:current_branch)}"

      Log.info "Publishing #{release_image_tag}"
      Run.docker "tag #{release_image_tag} #{latest_image_tag}"
      Run.docker "push #{release_image_tag}"
      Run.docker "push #{latest_image_tag}"
    end

    desc "deploy", "Perform k8s deployment with deploy hook"
    method_option :revision, required: false
    method_option :kubectl_context, required: false
    method_option :destination, required: false, default: "deployments,cronjobs"
    method_option :container, required: false, default: "*"
    method_option :all, required: false, type: :boolean, default: true
    def deploy
      revision = options[:revision] || Config.get!(:revision)
      kubectl_context = options[:kubectl_context] || Config.get!(:kubectl_context)
      Log.info "Current kubectl context: #{kubectl_context}"

      Log.info "Looking for deploy hook..."
      template_name, error, status = Open3.capture3 "kubectl get cronjob deploy-hook-template -n #{Config.get!(:namespace)} -o name --ignore-not-found=true"

      slack_notification = SlackNotification.get
      honeycomb_notification = HoneycombNotification.get

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
            slack_notification.failure if slack_notification.configured?
            honeycomb_notification.failure
            exit(1)
          end
        end
      else
        Log.info "Error getting deploy hook template: #{error}"
        slack_notification.failure if slack_notification.configured?
        honeycomb_notification.failure
        exit(1)
      end

      destination = options[:destination]
      container = options[:container]
      all = options[:all]
      Log.info "Set kubectl image for #{all ? 'all ' : ''}#{destination} container=#{container}..."
      Run.kubectl "set image #{destination} #{container}=#{Config.get!(:image)}:#{revision} #{all ? '--all' : ''}"
    end

    desc "set_image", "Set image for k8s deployment"
    method_option :revision, required: false
    method_option :kubectl_context, required: false
    method_option :destination, required: false, default: "deployments,cronjobs"
    method_option :container, required: false, default: "*"
    method_option :all, required: false, type: :boolean, default: true
    def set_image
      revision = options[:revision] || Config.get!(:revision)
      kubectl_context = options[:kubectl_context] || Config.get!(:kubectl_context)
      Log.info "Current kubectl context: #{kubectl_context}"

      destination = options[:destination]
      container = options[:container]
      all = options[:all]
      Log.info "Set kubectl image for #{all ? 'all ' : ''}#{destination} container=#{container}..."
      Run.kubectl "set image #{destination} #{container}=#{Config.get!(:image)}:#{revision} #{all ? '--all' : ''}"
    end

    desc "release", "Build and publish docker images"
    def release
      Log.info "Build and release #{Config.get!(:image)}:#{Config.get!(:revision)}"
      pull
      Log.info "Building #{Config.get!(:release_stage_name)} image"
      Run.docker_compose "build #{Config.get!(:release_stage_name)}"
      publish
    end

    desc "monitor_deploy_status", "Check is deployment has finished and sends post-deploy notification"
    method_option :max_tries, required: false, default: "30"
    def monitor_deploy_status
      max_tries = options[:max_tries].to_i

      Log.info "Current kubectl context: #{Config.get!(:kubectl_context)}"
      Log.info "Checking if all containers in #{Config.get!(:namespace)} namespace(s) are ready (#{max_tries} tries)..."

      slack_notification = SlackNotification.get
      honeycomb_notification = HoneycombNotification.get

      deploy_status = Vidar::DeployStatus.new(namespace: Config.get!(:namespace), max_tries:)

      deploy_status.wait_until_completed

      if deploy_status.success?
        Log.info "OK: All containers are ready"
        slack_notification.success if slack_notification.configured?
        honeycomb_notification.success
        invoke :notify_sentry
      else
        Log.error "ERROR: Some of containers are errored or not ready"
        slack_notification.failure if slack_notification.configured?
        honeycomb_notification.failure
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

    desc "notify_honeycomb", "Send test honeycomb notification"
    def notify_honeycomb
      HoneycombNotification.get.success
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
