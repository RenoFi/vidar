module Vidar
  class DeployStatus
    INITIAL_SLEEP = 2
    SLEEP = 10
    MAX_TRIES = 30

    attr_reader :namespace, :filter

    def initialize(namespace:, filter: nil)
      @namespace = namespace
      @filter = filter
    end

    def error?
      any_errors = false
      tries = 0

      sleep(INITIAL_SLEEP)

      until K8s::Pods.new(namespace: namespace, filter: filter).all_ready?
        tries += 1
        sleep(SLEEP)
        if tries > MAX_TRIES
          any_errors = true
          break
        end
      end

      any_errors
    end

    def ok?
      !error?
    end
  end
end
