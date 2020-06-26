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

    describe '#send_profiling_flush' do
      subject(:response) { transport.send_profiling_flush(flush) }
      let(:flush) { get_test_profiling_flush }

      it do
        is_expected.to be_a(Datadog::Profiling::Transport::HTTP::Response)
        expect(response.ok?).to be true
      end
    end
  end
end
