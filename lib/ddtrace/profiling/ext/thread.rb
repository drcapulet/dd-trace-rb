require 'ffi'

module Datadog
  module Profiling
    module Ext
      # C-struct for retrieving clock ID from pthread
      class CClockId < FFI::Struct
        layout :value, :int
      end

      # Extensions for pthread-backed Ruby threads, to retrieve
      # the thread ID, clock ID, and CPU time.
      module CThread
        extend FFI::Library
        ffi_lib 'ruby', 'pthread'
        attach_function :rb_nativethread_self, [], :ulong
        attach_function :pthread_getcpuclockid, [:ulong, CClockId], :int

        def self.prepended(base)
          # Be sure to update the current thread too; as it won't have been set.
          unless Thread.current.native_thread_id
            Thread.current.instance_variable_set(:@native_thread_id, CThread.rb_nativethread_self)
          end
        end

        attr_reader :native_thread_id

        def initialize(*args)
          # Wrap the work block with our own
          # so we can retrieve the native thread ID within the thread's context.
          wrapped_block = proc do |*t_args|
            @native_thread_id = rb_nativethread_self
            yield(*t_args)
          end

          super(*args, &wrapped_block)
        end

        def clock_id
          return unless native_thread_id

          # Build a struct, pass it to Pthread's getcpuclockid function.
          clock = CClockId.new
          clock[:value] = 0
          return_code = pthread_getcpuclockid(native_thread_id, clock)
          raise CPUClockUnavailableError, native_thread_id, return_code if return_code != 0

          clock[:value]
        end

        def cpu_time(unit = :float_second)
          cpu_clock = clock_id
          return unless cpu_clock && Process.respond_to?(:clock_gettime)
          Process.clock_gettime(cpu_clock, unit)
        end

        # Error when the CPU clock cannot be retrieved for a thread because of an error.
        class CPUClockUnavailableError < StandardError
          attr_reader \
            :native_thread,
            :return_code

          def initialize(native_thread, return_code)
            @native_thread = native_thread
            @return_code = return_code
          end

          def message
            "Could not retrieve the CPU clock for thread #{native_thread}. Return code: #{return_code}"
          end
        end
      end
    end
  end
end
