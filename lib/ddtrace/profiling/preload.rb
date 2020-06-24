require 'ddtrace/profiling'

if Datadog::Profiling.supported?
  Datadog::Profiling::Tasks::Setup.new.execute
# rubocop:disable Style/EmptyElse
else
  # TODO: Log error?
  # puts '[DDTRACE] Profiling not supported; skipping preload.'
end
