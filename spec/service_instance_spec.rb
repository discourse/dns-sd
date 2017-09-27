require_relative './spec_helper'

require 'dns-sd/service_instance'

describe DNSSD::ServiceInstance do
  let(:mock_resolver) { instance_double(Resolv::DNS) }
  before(:each) do
    allow(Resolv::DNS).to receive(:new).and_return(mock_resolver)
  end

  let(:instance) do
    DNSSD::ServiceInstance.new(Resolv::DNS::Name.new(["\u00c4rgle B\u00e4rgle", "_http", "_tcp", "example", "com"]))
  end

  describe ".new" do
    it "works" do
      expect { instance }.to_not raise_error
    end

    it "doesn't accept strings" do
      expect { described_class.new("\u00c4rgle B\u00e4rgle._http._tcp.example.com") }.to raise_error(ArgumentError)
    end
  end

  describe "#name" do
    it "returns the name of the service instance" do
      expect(instance.name).to eq("Ärgle Bärgle")
    end
  end

  describe "#fqdn" do
    it "returns the FQDN of the service instance" do
      expect(instance.fqdn).to eq(Resolv::DNS::Name.new(["Ärgle Bärgle", "_http", "_tcp", "example", "com"]))
    end
  end

  describe "#service" do
    it "returns a reference to the associated service" do
      expect(instance.service).to be_a(DNSSD::Service)
      expect(instance.service.name).to eq("http")
      expect(instance.service.protocol).to eq(:TCP)
    end
  end

  describe "#data" do
    before(:each) do
      allow(mock_resolver).to receive(:getresources).with(any_args).and_return(dns_resource_fixture("basic_txt"))
    end

    it "returns the tags as a hash" do
      expect(instance.data).to eq(txtvers: "1", something: "\"funny\"", foo: "bar", baz: "", wombat: nil)
    end

    it "retrieves the TXT record from DNS" do
      expect(mock_resolver).to receive(:getresources)
        .with(
          Resolv::DNS::Name.new(["\u00c4rgle B\u00e4rgle", "_http", "_tcp", "example", "com"]),
          Resolv::DNS::Resource::IN::TXT
      )

      instance.data
    end

    it "caches responses" do
      expect(mock_resolver).to receive(:getresources).once

      instance.data
      instance.data
    end

    it "respects the TTL" do
      expect(mock_resolver).to receive(:getresources).twice
      expect(Time).to receive(:now).and_return(Time.at(t0 = 1234567890))
      expect(Time).to receive(:now).at_least(:once).and_return(Time.at(t0 + 120))

      instance.data
      instance.data
    end
  end

  describe "#targets" do
    before(:each) do
      allow(mock_resolver).to receive(:getresources).with(any_args).and_return(dns_resource_fixture("srv_list"))
    end

    it "returns the targets in a properly-computed order" do
      # RFC2782 ftw.  The SRV records returned will be ordered for selection as follows:
      # - p0w0
      # - p0w10
      # - p1w0
      # - p2w0a
      # - p2w0b
      # - p2w10
      # - p2w20

      # Phase 1: choosing between p0w0 and p0w10.

      # This should select p0w10.
      expect(instance).to receive(:rand).with(11).and_return(4).ordered
      # p0w0 now gets chosen as the only remaining target at this priority.
      expect(instance).to receive(:rand).with(1).and_return(0).ordered

      # Phase 2: choosing between p1w0 and... p1w0.  That's easy.
      expect(instance).to receive(:rand).with(1).and_return(0).ordered

      # Phase 3: choosing between p2w0a, p2w0b, p2w10, and p2w20.

      # This should (just barely) select p2w10.
      expect(instance).to receive(:rand).with(31).and_return(10).ordered
      # This should select p2w0a.
      expect(instance).to receive(:rand).with(21).and_return(0).ordered
      # This should select p2w20
      expect(instance).to receive(:rand).with(21).and_return(17).ordered
      # p2w0b should be chosen as the only remaining target at
      # this priority.
      expect(instance).to receive(:rand).with(1).and_return(0).ordered

      # Now, after all that, did it *work*?
      expect(instance.targets).to eq([
        DNSSD::Target.new("p0w10.example.com", 8010),
        DNSSD::Target.new("p0w0.example.com",  8000),
        DNSSD::Target.new("p1w0.example.com",  8100),
        DNSSD::Target.new("p2w10.example.com", 8210),
        DNSSD::Target.new("p2w0a.example.com", 8200),
        DNSSD::Target.new("p2w20.example.com", 8220),
        DNSSD::Target.new("p2w0b.example.com", 8200)
      ])
    end
  end
end
