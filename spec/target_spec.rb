require_relative './spec_helper'

require 'dns-sd/target'

describe DNSSD::Target do
  let(:target) do
    DNSSD::Target.new("foo.example.com", 80)
  end

  describe ".new" do
    it "works" do
      expect { target }.to_not raise_error
    end
  end

  describe "#hostname" do
    it "returns the name of the target" do
      expect(target.hostname).to eq("foo.example.com")
    end
  end

  describe "#port" do
    it "returns the port of the target" do
      expect(target.port).to eq(80)
    end
  end
end
