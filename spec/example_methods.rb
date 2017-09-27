require 'resolv'
require 'yaml'

module ExampleMethods
  def dns_resource_fixture(name)
    data = YAML.load_file(File.expand_path("../fixtures/dns_resources/#{name}.yml", __FILE__))
    data.map do |d|
      Resolv::DNS::Resource::IN.const_get(d["type"]).new(*d["data"]).tap do |rr|
        rr.instance_variable_set(:@ttl, d["ttl"])
      end
    end.sort_by { rand }
  end

  def dns_resource_fixtures(*names)
    names.map { |n| dns_resource_fixture(n) }.flatten(1).sort_by { rand }
  end
end
