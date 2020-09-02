module Vidar
  class Log
    class << self
      def line
        puts "|#{'-' * 142}|"
      end

      def info(text, fill_with = "#")
        puts ColorizedString["#{fill_with} #{text} ".ljust(124, fill_with)].colorize(:light_green)
      end

      def error(text, fill_with = "#")
        puts ColorizedString["#{fill_with} #{text} ".ljust(124, fill_with)].colorize(:light_red)
      end
    end
  end
end
