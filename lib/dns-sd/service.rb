require 'dns-sd/resource_cache'
require 'dns-sd/service_instance'

require 'resolv'

class DNSSD
  # The generic service.
  #
  # Allows you to get the list of instances of a given service.
  #
  class Service
    include DNSSD::ResourceCache

    # The name of the service, without the leading underscore.
    #
    # @return [String]
    #
    attr_reader :name

    # The protocol of the service.
    #
    # @return [Symbol] `:TCP` or `:UDP`.
    #
    attr_reader :protocol

    # Create the service.
    #
    # @param fqdn [Resolv::DNS::Name]
    #
    def initialize(fqdn)
      unless fqdn.is_a?(Resolv::DNS::Name)
        raise ArgumentError,
          "FQDN must be a Resolv::DNS::Name (got an instance of #{fqdn.class})"
      end

      @fqdn = fqdn

      if fqdn[0].to_s =~ /\A_([A-Za-z0-9][A-Za-z0-9-]+)\z/
        @name = $1
      else
        raise ArgumentError,
          "Invalid service name #{fqdn[0].inspect}; see RFC6763 s. 7"
      end

      @protocol = case fqdn[1].to_s.downcase
                  when "_tcp"
                    :TCP
                  when "_udp"
                    :UDP
                  else
                    raise ArgumentError,
                      "Invalid service protocol #{@protocol}, must be '_tcp' or '_udp'"
      end
    end

    # Create an object for a specific instance of this service.
    #
    # @param name [String] the name of the service instance.
    #
    # @return [DNSSD::ServiceInstance]
    #
    def instance(name)
      DNSSD::ServiceInstance.new(Resolv::DNS::Name.new([name] + @fqdn.to_a))
    end

    # Enumerate all existing instances of this service.
    #
    # @return [Hash<String, DNSSD::ServiceInstance>] objects for all the
    #   service instances, indexed by their names.
    #
    def instances
      {}.tap do |instances|
        cached_resources(@fqdn, Resolv::DNS::Resource::IN::PTR).each do |rr|
          i = DNSSD::ServiceInstance.new(rr.name)
          instances[i.name] = i
        end
      end
    end

    # Let us know how long until the cache expires.
    #
    # This can be handy if you've got something that wants to poll the record
    # repeatedly; this way we can be a bit more intelligent about when to
    # retry, since if we re-poll too often, we'll just get the cached data back
    # again anyway.
    #
    # @return [Time, nil] if the entry is currently cached, a Time instance
    #   will be returned indicating when the entry will expire (potentially
    #   this could be in the past, if the cache has expired).  If we have no
    #   knowledge of the entry, `nil` will be returned.
    #
    def cached_until
      entry_expiry_time(@fqdn, Resolv::DNS::Resource::IN::PTR)
    end
  end
end
