require 'ddtrace/transport/http/api/instance'
require 'ddtrace/transport/http/api/endpoint'
require 'ddtrace/transport/http/api/map'
require 'ddtrace/transport/http/api/spec'

require 'ddtrace/profiling/encoding/profile'
require 'ddtrace/profiling/transport/http/response'

module Datadog
  module Profiling
    module Transport
      module HTTP
        # Extensions for HTTP API Spec
        module API
          # Default API versions
          V1 = 'v1'.freeze

          module_function

          def defaults
            Datadog::Transport::HTTP::API::Map[
              V1 => Spec.new do |s|
                s.profiles = Endpoint.new(
                  '/profiling/v1/input'.freeze,
                  Profiling::Encoding::Profile::Protobuf
                )
              end
            ]
          end

          # API specification for profiling
          class Spec < Datadog::Transport::HTTP::API::Spec
            attr_accessor \
              :profiles

            def send_flushes(env, &block)
              raise NoProfilesEndpointDefinedError, self if profiles.nil?
              profiles.call(env, &block)
            end

            def encoder
              profiles.encoder
            end

            # Raised when profiles sent but no profiles endpoint is defined
            class NoProfilesEndpointDefinedError < StandardError
              attr_reader :spec

              def initialize(spec)
                @spec = spec
              end

              def message
                'No profiles endpoint is defined for API specification!'
              end
            end
          end

          # API instance for profiling
          class Instance < Datadog::Transport::HTTP::API::Instance
            def send_flushes(env)
              raise ProfilesNotSupportedError, spec unless spec.is_a?(Spec)

              spec.send_flushes(env) do |request_env|
                call(request_env)
              end
            end

            # Raised when profiles sent to API that does not support profiles
            class ProfilesNotSupportedError < StandardError
              attr_reader :spec

              def initialize(spec)
                @spec = spec
              end

              def message
                'Profiles not supported for this API!'
              end
            end
          end

          # API endpoint for profiling
          class Endpoint < Datadog::Transport::HTTP::API::Endpoint
            attr_reader \
              :encoder

            def initialize(path, encoder, options = {})
              super(:post, path)
              @encoder = encoder
            end

            def call(env, &block)
              env.body = encoder.encode(env.request.parcel.data)
              http_response = super(env, &block)
              Profiling::Transport::HTTP::Response.new(http_response)
            end
          end
        end
      end
    end
  end
end
