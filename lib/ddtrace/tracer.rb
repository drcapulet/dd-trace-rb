require 'thread'
require 'logger'

require 'ddtrace/span'
require 'ddtrace/buffer'
require 'ddtrace/writer'

# \Datadog global namespace that includes all tracing functionality for Tracer and Span classes.
module Datadog
  # A \Tracer keeps track of the time spent by an application processing a single operation. For
  # example, a trace can be used to track the entire time spent processing a complicated web request.
  # Even though the request may require multiple resources and machines to handle the request, all
  # of these function calls and sub-requests would be encapsulated within a single trace.
  class Tracer
    attr_reader :writer, :services
    attr_accessor :enabled

    # Global, memoized, lazy initialized instance of a logger that is used within the the Datadog
    # namespace. This logger outputs to +STDOUT+ by default, and is considered thread-safe.
    def self.log
      unless defined? @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      end
      @logger
    end

    # Initialize a new \Tracer used to create, sample and submit spans that measure the
    # time of sections of code. Available +options+ are:
    #
    # * +enabled+: set if the tracer submits or not spans to the local agent. It's enabled
    #   by default.
    def initialize(options = {})
      @enabled = options.fetch(:enabled, true)
      @writer = options.fetch(:writer, Datadog::Writer.new)
      @buffer = Datadog::SpanBuffer.new()

      @mutex = Mutex.new
      @spans = []
      @services = {}
    end

    # Set the information about the given service. A valid example is:
    #
    #   tracer.set_service_info('web-application', 'rails', 'web')
    def set_service_info(service, app, app_type)
      @services[service] = {
        'app' => app,
        'app_type' => app_type
      }
    end

    # Return a +span+ that will trace an operation called +name+. You could trace your code
    # using a <tt>do-block</tt> like:
    #
    #   tracer.trace('web.request') do |span|
    #     span.service = 'my-web-site'
    #     span.resource = '/'
    #     span.set_tag('http.method', request.request_method)
    #     do_something()
    #   end
    #
    # The <tt>tracer.trace()</tt> method can also be used without a block in this way:
    #
    #   span = tracer.trace('web.request', service: 'my-web-site')
    #   do_something()
    #   span.finish()
    #
    # Remember that in this case, calling <tt>span.finish()</tt> is mandatory.
    #
    # When a Trace is started, <tt>trace()</tt> will store the created span; subsequent spans will
    # become it's children and will inherit some properties:
    #
    #   parent = tracer.trace('parent')     # has no parent span
    #   child  = tracer.trace('child')      # is a child of 'parent'
    #   child.finish()
    #   parent.finish()
    #   parent2 = tracer.trace('parent2')   # has no parent span
    #   parent2.finish()
    #
    def trace(name, options = {})
      span = Span.new(self, name, options)

      # set up inheritance
      parent = @buffer.get()
      span.set_parent(parent)
      @buffer.set(span)

      # call the finish only if a block is given; this ensures
      # that a call to tracer.trace() without a block, returns
      # a span that should be manually finished.
      begin
        yield(span) if block_given?
      rescue StandardError => e
        span.set_error(e)
        raise
      ensure
        span.finish() if block_given?
      end

      span
    end

    # Record the given finished span in the +spans+ list. When a +span+ is recorded, it will be sent
    # to the Datadog trace agent as soon as the trace is finished.
    def record(span)
      spans = []
      @mutex.synchronize do
        @spans << span
        parent = span.parent
        @buffer.set(parent)

        return unless parent.nil?
        spans = @spans
        @spans = []
      end

      return if spans.empty?
      write(spans)
    end

    # Return the current active span or +nil+.
    def active_span
      @buffer.get()
    end

    def write(spans)
      return if @writer.nil? || !@enabled
      @writer.write(spans, @services)
    end

    private :write
  end
end