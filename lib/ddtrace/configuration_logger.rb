require 'date'
require 'rbconfig'

module Datadog
  # Add docs here TODO
  # TODO: detect if running on REPL, then don't print this
  # rubocop:disable Style/DoubleNegation
  class ConfigurationLogger
    # DEV: should we dump all, except keys marked as :dont_dump?

    def date
      DateTime.now.iso8601
    end

    def os_name
      RbConfig::CONFIG['host']
    end

    def version
      VERSION::STRING
    end

    def lang
      Ext::Runtime::LANG
    end

    def lang_version
      Ext::Runtime::LANG_VERSION
    end

    def env
      Datadog.configuration.env
    end

    def enabled
      Datadog.configuration.tracer.enabled
    end

    def service
      Datadog.configuration.service
    end

    def agent_url
      transport = Datadog.tracer.writer.transport
      adapter = transport.client.api.adapter
      adapter.url
    end

    def agent_error(transport_responses)
      error_responses = transport_responses.reject(&:ok?)

      return nil if error_responses.empty?

      error_responses.map(&:inspect).join(',')
    end

    def debug
      !!Datadog.configuration.diagnostics.debug
    end

    def analytics_enabled
      !!Datadog.configuration.analytics.enabled
    end

    def sample_rate
      sampler = Datadog.configuration.tracer.sampler
      return nil unless sampler

      sampler.sample_rate(nil)
    end

    def sampling_rules
      sampler = Datadog.configuration.tracer.sampler
      return nil unless sampler.is_a?(Datadog::PrioritySampler) &&
                        sampler.priority_sampler.is_a?(Datadog::Sampling::RuleSampler)

      sampler.priority_sampler.rules.map do |rule|
        # TODO: write explanation on only supporing simple rule
        next unless rule.is_a?(Datadog::Sampling::SimpleRule)

        {
          name: rule.matcher.name,
          service: rule.matcher.service,
          sample_rate: rule.sampler.sample_rate(nil)
        }
      end.compact
    end

    def tags
      tags = Datadog.configuration.tags
      return nil if tags.empty?
      hash_serializer(tags)
    end

    def runtime_metrics_enabled
      Datadog.configuration.runtime_metrics.enabled
    end

    def integrations_loaded
      instrumented_integrations.keys.map(&:to_s).join(',')
    end

    # TODO: todo
    # def <integration>_analytics_enabled
    #
    # end

    # TODO: todo
    # def <integration>_sample_rate
    #
    # end

    def vm
      "#{RUBY_ENGINE}-#{RUBY_ENGINE_VERSION}"
    end

    def partial_flushing_enabled
      !!Datadog.configuration.tracer.partial_flush.enabled
    end

    def priority_sampling_enabled
      !!Datadog.configuration.tracer.priority_sampling
    end

    def instrumented_integrations
      Datadog.configuration.instrumented_integrations
    end

    # TODO: send hash directly to logger? and let logger format, if they to_s it's not too bad
    def collect!(transport_responses)
      {
        date: date,
        os_name: os_name,
        version: version,
        lang: lang,
        lang_version: lang_version,
        env: env,
        enabled: enabled,
        service: service,
        agent_url: agent_url,
        agent_error: agent_error(transport_responses),
        debug: debug,
        analytics_enabled: analytics_enabled,
        sample_rate: sample_rate,
        sampling_rules: sampling_rules,
        tags: tags,
        runtime_metrics_enabled: runtime_metrics_enabled,
        integrations_loaded: integrations_loaded,
        vm: vm,
        partial_flushing_enabled: partial_flushing_enabled,
        priority_sampling_enabled: priority_sampling_enabled,
        **Hash[instrumented_integrations.flat_map do |name, integration|
          integration.configuration.to_h.map do |setting, value|
            next if setting == :tracer
            [:"#{name}_#{setting}", value]
          end
        end]
      }
    end

    def to_log_line(transport_responses)
      collect!(transport_responses).compact.to_json
    end

    def hash_serializer(h)
      h.map { |k, v| "#{k}:#{v}" }.join(',')
    end
  end
end
