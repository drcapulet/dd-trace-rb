require 'spec_helper'

require 'ddtrace/configuration_logger'

RSpec.describe Datadog::ConfigurationLogger do
  subject(:logger) { described_class.new }

  before do
    expect(DateTime).to receive(:now).and_return(DateTime.new(2020))
  end

  # context '#to_log_line' do
  #   subject(:to_log_line) { logger.to_log_line }
  #   it do
  #     pp subject
  #   end
  # end

  context '#collect!' do
    subject(:collect!) { logger.collect!([response]) }
    let(:response) { instance_double(Datadog::Transport::Response, ok?: true) }

    xit do
      is_expected.to eq(
        agent_error: nil,
        agent_url: 'http://127.0.0.1:8126?timeout=1',
        analytics_enabled: false,
        date: '2020-01-01T00:00:00+00:00',
        debug: false,
        enabled: true,
        env: nil,
        integrations_loaded: nil,
        lang: 'ruby',
        lang_version: Datadog::Ext::Runtime::LANG_VERSION,
        os_name: 'x86_64-apple-darwin18',
        partial_flushing_enabled: false,
        priority_sampling_enabled: false,
        runtime_metrics_enabled: false,
        sample_rate: nil,
        sampling_rules: nil,
        service: nil,
        tags: nil,
        version: Datadog::VERSION::STRING
      )
    end

    context 'with tracer disabled' do
      before { Datadog.configure { |c| c.tracer.enabled = false } }

      it { is_expected.to include enabled: false }
    end

    context 'with env configured' do
      before { Datadog.configure { |c| c.env = 'env' } }

      it { is_expected.to include env: 'env' }
    end

    context 'with tags configured' do
      before { Datadog.configure { |c| c.tags = { 'k1' => 'v1', 'k2' => 'v2' } } }

      it { is_expected.to include tags: 'k1:v1,k2:v2' }
    end

    context 'with service configured' do
      before { Datadog.configure { |c| c.service = 'svc' } }

      it { is_expected.to include service: 'svc' }
    end

    context 'with debug enabled' do
      before { Datadog.configure { |c| c.diagnostics.debug = true } }

      it { is_expected.to include debug: true }
    end

    context 'with analytics enabled' do
      before { Datadog.configure { |c| c.analytics_enabled = true } }

      it { is_expected.to include analytics_enabled: true }
    end

    context 'with runtime metrics enabled' do
      before { Datadog.configure { |c| c.runtime_metrics_enabled = true } }

      it { is_expected.to include runtime_metrics_enabled: true }
    end

    context 'with partial flushing enabled' do
      before { Datadog.configure { |c| c.tracer.partial_flush.enabled = true } }

      it { is_expected.to include partial_flushing_enabled: true }
    end

    context 'with priority sampling enabled' do
      before { Datadog.configure { |c| c.tracer.priority_sampling = true } }

      it { is_expected.to include priority_sampling_enabled: true }
    end

    context 'with agent connectivity issues' do
      let(:response) { Datadog::Transport::InternalErrorResponse.new(ZeroDivisionError.new('msg')) }

      it { is_expected.to include agent_error: include('ZeroDivisionError') }
      it { is_expected.to include agent_error: include('msg') }
    end

    context 'with unix socket transport' do
      before do
        Datadog.configure do |c|
          c.tracer.transport_options = ->(t) { t.adapter :unix, '/tmp/trace.sock' }
        end
      end

      it { is_expected.to include agent_url: include('unix') }
      it { is_expected.to include agent_url: include('/tmp/trace.sock') }
    end

    context 'with integrations loaded' do
      before { Datadog.configure { |c| c.use :http, options } }
      let(:options) { {} }

      it { is_expected.to include integrations_loaded: 'http' }

      context 'with integration-specific settings' do
        let(:options) { { service_name: 'my-http' } }

        it { is_expected.to include http_analytics_enabled: false }
        it { is_expected.to include http_analytics_sample_rate: 1.0 }
        it { is_expected.to include http_service_name: 'my-http' }
        it { is_expected.to include http_distributed_tracing: true }
        it { is_expected.to include http_split_by_domain: false }
      end
    end

    context 'with MRI' do
      before { skip unless PlatformHelpers.mri? }

      it { is_expected.to include vm: start_with('ruby') }
    end

    context 'with JRuby' do
      before { skip unless PlatformHelpers.jruby? }

      it { is_expected.to include vm: start_with('jruby') }
    end
  end
end
