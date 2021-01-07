module Vidar
  class Interpolation
    INTERPOLATION_PATTERN = /\{\{(\w+)\}\}/

    class << self
      def call(string, getter)
        return unless string
        fail ArgumentError, "getter must respond_to get." unless getter.respond_to?(:get)

        string.gsub(INTERPOLATION_PATTERN) do |match|
          getter.get($1) || ENV[$1] || match # rubocop:disable Style/PerlBackrefs
        end
      end
    end
  end
end
