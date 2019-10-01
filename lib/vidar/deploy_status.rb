module Vidar
  class DeployStatus
    INITIAL_SLEEP = 2
    SLEEP = 10
    MAX_TRIES = 30

    attr_reader :namespace, :filter, :max_tries

    def initialize(namespace:, filter: nil, max_tries: MAX_TRIES)
      @namespace = namespace
      @filter = filter
      @max_tries = max_tries
    end

    def wait_until_completed
      tries = 0

      sleep(INITIAL_SLEEP)

      until pod_set.deployed?
        tries += 1
        sleep(SLEEP)
        if tries > max_tries
          break
        end
      end
    end

    def success?
      return false unless last_pod_set
      last_pod_set.success?
    end

    def last_pod_set
      @pod_set
    end

    def pod_set
      @pod_set = K8s::PodSet.new(namespace: namespace, filter: filter)
    end
  end
end
