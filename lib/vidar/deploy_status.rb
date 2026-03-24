module Vidar
  # Polls Kubernetes pod status until deployment completes or times out.
  class DeployStatus
    INITIAL_SLEEP = 2
    SLEEP = 10
    MAX_TRIES = 30

    attr_reader :namespace, :filter, :max_tries

    # @param namespace [String] Kubernetes namespace, or "all"
    # @param filter [String, nil] optional substring filter on container names
    # @param max_tries [Integer] maximum poll iterations before giving up
    def initialize(namespace:, filter: nil, max_tries: MAX_TRIES)
      @namespace = namespace
      @filter = filter
      @max_tries = max_tries
    end

    # Waits until at least one pod exists in the namespace.
    # @return [void]
    def wait_until_up
      sleep(INITIAL_SLEEP)

      max_tries.times do
        ps = current_pod_set
        break if ps.any?

        sleep(SLEEP)
      end
    end

    # Waits until all pods are deployed and none are still initializing.
    # @return [void]
    def wait_until_completed
      sleep(INITIAL_SLEEP)

      max_tries.times do
        ps = current_pod_set
        break if ps.deployed?

        sleep(SLEEP)
      end
    end

    # @return [Boolean] true if the last observed pod set reported success
    def success?
      return false unless @last_pod_set

      @last_pod_set.success?
    end

    private

    def current_pod_set
      @last_pod_set = K8s::PodSet.new(namespace:, filter:)
    end
  end
end
