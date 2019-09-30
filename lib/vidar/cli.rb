module Vidar
  class CLI < Thor
    include Thor::Shell

    def self.exit_on_failure?
      true
    end

    desc "run_runner", "Runs any given command in runner image"
    option :command
    def run_runner
      Run.docker_compose("run runner #{options[:command]}") || exit(1)
    end

    desc "pull", "Pulls existing docker images to leverage docker caching"
    def pull
      Log.info "Pulling #{Config.get!(:image)} tags"
      Run.docker "pull #{Config.get!(:image)}:builder-#{Config.get!(:current_branch)} 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:builder 2> /dev/null || true"
      Run.docker "pull #{Config.get!(:image)}:release 2> /dev/null || true"
      Log.info "Docker images:"
      Log.info Run.docker("images")
    end

    desc "build", "Builds docker stages"
    def build
      Log.info "Building #{Config.get!(:image)}:builder-#{Config.get!(:current_branch)}"
      Run.docker_compose "build builder"

      Log.info "Building #{Config.get!(:image)}:runner-#{Config.get!(:current_branch)}"
      Run.docker_compose "build runner"

      Log.info "Building #{Config.get!(:image)}:release"
      Run.docker_compose "build release"
    end

    desc "cache", "Caches intermediate docker stages"
    def cache
      Log.info "Publish #{Config.get!(:image)}:builder-#{Config.get!(:current_branch)}"
      Run.docker "push #{Config.get!(:image)}:builder-#{Config.get!(:current_branch)}"
    end

    desc "publish", "Publishes docker images on docker registry"
    def publish
      Log.info "Publish #{Config.get!(:image)}:#{Config.get!(:revision)}"
      Run.docker "tag #{Config.get!(:image)}:release #{Config.get!(:image)}:#{Config.get!(:revision)}"
      Run.docker "push #{Config.get!(:image)}:#{Config.get!(:revision)}"

      return unless Config.get!(:current_branch) == Config.get!(:default_branch)

      Log.info "Publish #{Config.get!(:image)}:builder"
      Run.docker "tag #{Config.get!(:image)}:builder-#{Config.get!(:current_branch)} #{Config.get!(:image)}:builder"
      Run.docker "push #{Config.get!(:image)}:builder"

      Log.info "Publish #{Config.get!(:image)}:latest"
      Run.docker "tag #{Config.get!(:image)}:release #{Config.get!(:image)}:latest"
      Run.docker "push #{Config.get!(:image)}:release"
      Run.docker "push #{Config.get!(:image)}:latest"
    end

    desc "deploy", "Performs k8s deployment with deploy hook"
    method_option :revision, default: nil
    def deploy
      revision = options[:revision] || Config.get!(:revision)
      Log.info "Current cluster_name: #{Config.get!(:cluster_name)} ###"

      Log.info "Set kubectl image..."
      Run.kubectl "set image deployments,cronjobs *=#{Config.get!(:image)}:#{revision} --all"

      Log.info "Looking for deploy hook..."
      template_name, error, status = Open3.capture3 "kubectl get cronjob deploy-hook-template -n #{Config.get!(:namespace)} -o name --ignore-not-found=true"

      if status.success?
        if template_name.to_s.empty?
          Log.info "No deploy hook found"
        else
          Log.info "Executing deploy hook #{template_name.strip!}..."
          Run.kubectl "delete job deploy-hook --ignore-not-found=true"
          Run.kubectl "create job deploy-hook --from=#{template_name}"
        end
      else
        Log.info "Error getting deploy hook template: #{error}"
        exit(1)
      end
    end

    desc "release", "Builds and publishes docker images"
    def release
      Log.info "Release #{options[:image]}:#{options[:revision]}"
      pull
      build
      cache
      publish
    end

    desc "monitor_deploy_status", "Checks is deployment has finished and sends post-deploy notification"
    method_option :success_color, required: false
    method_option :error_color, required: false
    def monitor_deploy_status
      Log.info "Current cluster_name: #{Config.get!(:cluster_name)} ###"
      Log.info "Checking is all containers on #{Config.get!(:cluster_name)} in #{Config.get!(:namespace)} are ready..."

      slack_notification = SlackNotification.new(
        webhook_url:   Config.get!(:slack_webhook_url),
        github:        Config.get!(:github),
        revision:      Config.get!(:revision),
        revision_name: Config.get!(:revision_name),
        cluster_label: Config.get!(:cluster_label),
        cluster_url:   Config.get!(:cluster_url),
        success_color: options[:success_color],
        error_color:   options[:error_color],
      )

      ok = Vidar::DeployStatus.new(Config.get!(:namespace)).ok?

      if ok
        Log.info "OK: All containers are ready."
        slack_notification.success if slack_notification.configured?
      else
        Log.error "ERROR: Some of containers are not ready."
        slack_notification.error if slack_notification.configured?
        exit(1)
      end
    end
  end
end
