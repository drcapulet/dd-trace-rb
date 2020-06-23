require 'spec_helper'
require 'ddtrace/profiling/spec_helper'

require 'ddtrace'
require 'ddtrace/profiling/transport/http'

RSpec.describe 'Datadog::Profiling::Transport::HTTP integration tests' do
  before { skip unless ENV['TEST_DATADOG_INTEGRATION'] }

  describe 'HTTP#default' do
    subject(:transport) { Datadog::Profiling::Transport::HTTP.default(&client_options) }
    let(:client_options) { proc { |_client| } }
    it { is_expected.to be_a(Datadog::Profiling::Transport::HTTP::Client) }

    describe '#send_flushes' do
      subject(:responses) { transport.send_flushes(flushes) }
      let(:flushes) { get_test_profiling_flushes }

      before { skip 'Test not ready.' }

      it do
        is_expected.to all(be_a(Datadog::Profiling::Transport::HTTP::Response))

        expect(responses).to have(1).item
        response = responses.first
        expect(response.ok?).to be true
      end
    end
  end
end
