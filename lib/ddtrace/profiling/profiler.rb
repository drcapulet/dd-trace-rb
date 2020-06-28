require 'ddtrace/profiling/collectors/stack'
require 'ddtrace/profiling/exporter'
require 'ddtrace/profiling/recorder'
require 'ddtrace/profiling/scheduler'
require 'ddtrace/profiling/transport/io'

module Datadog
  class Profiler
    attr_reader \
      :collectors,
      :scheduler

    def initialize(collectors, scheduler)
      @collectors = collectors
      @scheduler = scheduler
    end

    def start
      collectors.each(&:start)
      scheduler.start
    end

    def shutdown!
      collectors.each do |collector|
        collector.enabled = false
        collector.stop(true)
      end

      scheduler.enabled = false
      scheduler.stop(true)
    end
  end
end
