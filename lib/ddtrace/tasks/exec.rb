module Datadog
  module Tasks
    # Wraps command with Datadog tracing
    class Exec
      def initialize(args)
        @args = args
      end

      def run
        set_rubyopt!
        Kernel.exec(*@args)
      end

      def set_rubyopt!
        if ENV.key?('RUBYOPT')
          ENV['RUBYOPT'] += " #{rubyopts.join(' ')}"
        else
          ENV['RUBYOPT'] = rubyopts.join(' ')
        end
      end

      def rubyopts
        [
          '-rddtrace/profiling/preload'
        ]
      end
    end
  end
end
