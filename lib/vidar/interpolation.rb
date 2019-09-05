module Vidar
  class Interpolation
    INTERPOLATION_PATTERN = /\{\{(\w+)\}\}/.freeze

    class << self
      def call(string, getter)
        return unless string
        fail ArgumentError, "getter must respond_to get." unless getter.respond_to?(:get)

        string.gsub(INTERPOLATION_PATTERN) do |match|
          getter.get($1) || match
        end
      end
    end
  end
end
