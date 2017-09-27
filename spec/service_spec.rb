require_relative './spec_helper'

require 'dns-sd/service'

describe DNSSD::Service do
  use_mock_resolver

  let(:service) do
    DNSSD::Service.new(Resolv::DNS::Name.new(["_http", "_tcp", "example", "com"]))
  end

  describe ".new" do
    it "works" do
      expect { service }.to_not raise_error
    end

    it "doesn't accept strings" do
      expect { described_class.new("_http._tcp.example.com") }.to raise_error(ArgumentError)
    end

    it "doesn't accept service names without underscores" do
      expect { described_class.new(Resolv::DNS::Name.new(["http", "_tcp", "example", "com"])) }.to raise_error(ArgumentError)
    end

    it "doesn't accept mysterious protocols" do
      expect { described_class.new(Resolv::DNS::Name.new(["_http", "tcp", "example", "com"])) }.to raise_error(ArgumentError)
    end
  end

  describe "#name" do
    it "returns the name of the service" do
      expect(service.name).to eq("http")
    end
  end

  describe "#protocol" do
    it "returns the protocol identifier" do
      expect(service.protocol).to eq(:TCP)
    end
  end

  describe "#instance" do
    let(:instance) { service.instance("faff") }

    it "returns a ServiceInstance" do
      expect(instance).to be_a(DNSSD::ServiceInstance)
    end

    it "has the right name" do
      expect(instance.name).to eq("faff")
    end
  end

  describe "#instances" do
    before(:each) do
      allow(mock_resolver).to receive(:getresources).with(any_args).and_return(dns_resource_fixture("http_ptr_list"))
    end

    it "queries DNS" do
      expect(mock_resolver).to receive(:getresources)
        .with(
          Resolv::DNS::Name.create("_http._tcp.example.com."),
          Resolv::DNS::Resource::IN::PTR
      )

      service.instances
    end

    it "caches responses" do
      expect(mock_resolver).to receive(:getresources).once

      service.instances
      service.instances
    end

    it "returns a hash of instances" do
      expect(service.instances).to be_a(Hash)
    end

    it "returns our instances" do
      expect(service.instances["faff"].name).to eq("faff")
      expect(service.instances["wombat"].name).to eq("wombat")
    end
  end

  describe "#cached_until" do
    before(:each) do
      allow(mock_resolver).to receive(:getresources).with(any_args).and_return(dns_resource_fixture("http_ptr_list"))
    end

    it "returns nil if no request made yet" do
      expect(service.cached_until).to eq(nil)
    end

    it "returns now+expiry after resource request" do
      service.instances

      expect(service.cached_until).to be_within(0.01).of(Time.now + 60)
    end
  end
end
