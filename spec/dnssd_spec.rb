require_relative './spec_helper'

require 'dns-sd'

describe DNSSD do
  use_mock_resolver

  let(:dnssd) do
    DNSSD.new("example.com")
  end

  describe ".new" do
    it "works" do
      expect { dnssd }.to_not raise_error
    end

    it "accepts a Resolv::DNS::Name, too" do
      expect(DNSSD.new(Resolv::DNS::Name.new(["example", "com"])).domain).to eq("example.com")
    end
  end

  describe "#domain" do
    it "returns the DNS-SD base domain" do
      expect(dnssd.domain).to eq("example.com")
    end
  end

  describe "#service" do
    let(:service) { dnssd.service("http", :TCP) }

    it "creates a new DNSSD::Service" do
      expect(service).to be_a(DNSSD::Service)
    end

    it "has the correct characteristics" do
      expect(service.name).to eq("http")
      expect(service.protocol).to eq(:TCP)
    end

    it "doesn't like rando protocols" do
      expect { dnssd.service("http", "faff") }.to raise_error(ArgumentError)
    end

    it "recognises UDP" do
      expect(dnssd.service("domain", :UDP).protocol).to eq(:UDP)
    end
  end

  describe "#service_instance" do
    let(:instance) { dnssd.service_instance("blingle", "http", :TCP) }

    it "creates a new DNSSD::ServiceInstance" do
      expect(instance).to be_a(DNSSD::ServiceInstance)
    end

    it "has the correct characteristics" do
      expect(instance.name).to eq("blingle")
      expect(instance.service.name).to eq("http")
      expect(instance.service.protocol).to eq(:TCP)
    end
  end

  describe "#services" do
    before(:each) do
      allow(mock_resolver).to receive(:getresources).with(any_args).and_return(dns_resource_fixture("service_ptrs"))
    end

    it "queries DNS" do
      expect(mock_resolver).to receive(:getresources).with(
        Resolv::DNS::Name.new(["_services", "_dns-sd", "_udp", "example", "com"]),
        Resolv::DNS::Resource::IN::PTR
      )

      dnssd.services
    end

    it "returns a hash of the available services" do
      expect(dnssd.services).to be_a(Hash)
    end

    it "returns the services" do
      expect(dnssd.services["http"]).to be_a(DNSSD::Service)
      expect(dnssd.services["xmpp"]).to be_a(DNSSD::Service)
    end
  end
end
