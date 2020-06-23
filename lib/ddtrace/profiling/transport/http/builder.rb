require 'ddtrace/transport/http/builder'

require 'ddtrace/profiling/transport/http/api'
require 'ddtrace/profiling/transport/http/client'

module Datadog
  module Profiling
    module Transport
      module HTTP
        # Builds new instances of Transport::HTTP::Client
        class Builder < Datadog::Transport::HTTP::Builder
          def api_instance_class
            API::Instance
          end

          def to_transport
            raise Datadog::Transport::HTTP::Builder::NoDefaultApiError if @default_api.nil?
            Client.new(to_api_instances, @default_api)
          end
        end
      end
    end
  end
end
