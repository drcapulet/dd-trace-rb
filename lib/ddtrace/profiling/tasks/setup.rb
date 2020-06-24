module Datadog
  module Profiling
    module Tasks
      # Sets up profiling for the application
      class Setup
        # rubocop:disable Lint/HandleExceptions
        def execute
          require 'ddtrace/profiling/ext/thread'
          ::Thread.send(:prepend, Profiling::Ext::CThread)
        rescue StandardError => _e
          # TODO: Log error?
          # puts "[DDTRACE] CPU profiling unavailable. Cause: #{e.message} Location: #{e.backtrace.first}"
        end
      end
    end
  end
end
