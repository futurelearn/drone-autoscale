require 'spec_helper'
require 'webmock/rspec'
require 'timecop'
require 'json'

require 'drone_autoscale/server'

RSpec.describe Server do
  let(:api_endpoint) { "http://localhost/api/info/queue" }
  let(:drone_api_token) { "some-fake-token" }
  let(:default_stats) do
    {
      "pending": "null",
      "running": "null",
      "stats": {
        "worker_count": 3,
        "pending_count": 2,
        "running_count": 5,
        "completed_count": 0
      }
    }
  end

  let(:client) { double(:client) }

  before(:each) do
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(client)
    stub_request(:get, api_endpoint).to_return(body: JSON.dump(default_stats))
  end

  subject { described_class.new(drone_api_token: drone_api_token) }

  describe '#api_stats' do
    it 'should contain the authorization header' do
      subject.api_stats
      expect(WebMock).to have_requested(:get, api_endpoint).with { |request|
        expect(request.headers).to include('Authorization' => 'some-fake-token')
      }
    end

    it 'returns JSON of worker stats' do
      result = subject.api_stats
      expect(result).to include(
        'worker_count' => 3,
        'pending_count' => 2,
        'running_count' => 5,
      )
    end
  end

  describe '#idle_workers' do
    it 'returns the number of idle workers/agents' do
      expect(subject.idle_workers).to eq(3)
    end
  end

  before do
    stub_request(:get, api_endpoint).to_return(body: JSON.dump(default_stats))
  end

  describe '#pending_jobs' do
    it 'returns the number of pending jobs' do
      expect(subject.pending_jobs).to eq(2)
    end
  end

  describe '#running_jobs' do
    it 'returns the number of running jobs' do
      expect(subject.running_jobs).to eq(5)
    end
  end

  describe '#total_jobs' do
    it 'returns the number of total jobs' do
      expect(subject.total_jobs).to eq(7)
    end
  end

  describe '#run' do
    before do
      Timecop.freeze(Time.now)
    end
    after do
      Timecop.return
    end
    let(:metrics) {{
      namespace: 'Drone',
      metric_data: [
        {
          metric_name: 'IdleWorkers',
          timestamp: Time.now,
          value: 3,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'RunningJobs',
          timestamp: Time.now,
          value: 5,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'PendingJobs',
          timestamp: Time.now,
          value: 2,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'TotalJobs',
          timestamp: Time.now,
          value: 7,
          unit: 'Count',
          storage_resolution: 1
        }
      ]
    }}
    it 'should put metric data for all metrics' do
      allow(client).to receive(:put_metric_data).with(metrics)
      expect(subject.run).to eq(true)
    end
  end
end