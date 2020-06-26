require 'ddtrace/utils/compression'
require 'ddtrace/vendor/multipart-post/multipart/post/composite_read_io'

require 'ddtrace/transport/http/api/instance'
require 'ddtrace/transport/http/api/endpoint'
require 'ddtrace/transport/http/api/map'
require 'ddtrace/transport/http/api/spec'

require 'ddtrace/ext/profiling'
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

            def send_profiling_flush(env, &block)
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
            def send_profiling_flush(env)
              raise ProfilesNotSupportedError, spec unless spec.is_a?(Spec)

              spec.send_profiling_flush(env) do |request_env|
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
            include Datadog::Ext::Profiling::Transport::HTTP

            attr_reader \
              :encoder

            def initialize(path, encoder, options = {})
              super(:post, path)
              @encoder = encoder
            end

            def call(env, &block)
              # Build request
              env.form = build_form(env)

              # Send request
              http_response = super(env, &block)

              # Build response
              Profiling::Transport::HTTP::Response.new(http_response)
            end

            def build_form(env)
              flush = env.request.parcel.data
              pprof = build_pprof(flush)

              form = {
                FORM_FIELD_RUNTIME_ID => flush.runtime_id,
                FORM_FIELD_RECORDING_START => flush.start.utc.iso8601,
                FORM_FIELD_RECORDING_END => flush.finish.utc.iso8601,
                FORM_FIELD_RUNTIME => flush.runtime,
                FORM_FIELD_FORMAT => FORM_FIELD_FORMAT_PPROF,
                FORM_FIELD_TYPE => FORM_FIELD_TYPE_CPU_TIME_WALL_TIME,
                FORM_FIELD_CHUNK_DATA => pprof,
                FORM_FIELD_TAGS => [
                  "#{FORM_FIELD_TAG_RUNTIME}:#{flush.runtime}",
                  "#{FORM_FIELD_TAG_RUNTIME_VERSION}:#{flush.runtime_version}",
                  "#{FORM_FIELD_TAG_PROFILER_VERSION}:#{flush.profiler_version}",
                  "#{FORM_FIELD_TAG_LANGUAGE}:#{flush.language}",
                  "#{FORM_FIELD_TAG_HOST}:#{flush.host}",
                ]
              }

              # Optional fields
              form[FORM_FIELD_TAGS] << "#{FORM_FIELD_TAG_SERVICE}:#{flush.service}" unless flush.service.nil?
              form[FORM_FIELD_TAGS] << "#{FORM_FIELD_TAG_ENV}:#{flush.env}" unless flush.env.nil?
              form[FORM_FIELD_TAGS] << "#{FORM_FIELD_TAG_VERSION}:#{flush.version}" unless flush.version.nil?

              form
            end

            def build_pprof(flush)
              pprof = encoder.encode(flush)
              gzipped_data = Datadog::Utils::Compression.gzip(pprof)

              # Send pprof as a file
              Datadog::Vendor::Multipart::Post::UploadIO.new(
                StringIO.new(gzipped_data),
                HEADER_CONTENT_TYPE_OCTET_STREAM,
                PPROF_DEFAULT_FILENAME
              )
            end
          end
        end
      end
    end
  end
end
