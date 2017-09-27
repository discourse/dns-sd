require 'dns-sd/resource_cache'
require 'dns-sd/service'

require 'resolv'

# Interact with RFC6763 DNS-SD records.
#
# Given a domain to work in, instances of this class use the standard Ruby DNS
# resolution mechanisms to look up services, service instances, and the
# individual servers that make up service instances.  You can also obtain the
# "metadata" associated with service instances.
#
# If you know the service, or even service instance, you wish to connect to,
# you can go straight there, using #service or #service_instance (as
# appropriate).  Otherwise, if you're just curious about what is available, you
# can use #services to get a list of everything advertised under the "Service
# Type Enumeration" record for the domain.
#
class DNSSD
  include DNSSD::ResourceCache

  # Create a new DNS-SD instance.
  #
  # @param domain [String, Resolv::DNS::Name] Specify the base domain under
  #   which all the records we're interested in are registered.
  #
  def initialize(domain)
    @domain = if domain.is_a?(Resolv::DNS::Name)
      domain
    else
      Resolv::DNS::Name.create(domain)
    end
  end

  # The current search domain.
  #
  # @return [String]
  #
  def domain
    @domain.to_s
  end

  # Create a new instance of DNSSD::Service for this given name and protocol.
  #
  # If you know the name and protocol of the service you wish to query for,
  # this is the method for you!  Note that just calling this method doesn't
  # make any DNS requests, so you may get a service that has no instances.
  #
  # @param name [String] the name of the service, *without* the leading
  #   underscore that goes into the DNS name.
  #
  # @param protocol [Symbol] One of `:TCP` or `:UDP`, to indicate that you want
  #   to talk to a TCP or non-TCP service, respectively.  Yes, `:UDP` means
  #   "non-TCP"; for more laughs, read RFC6763 s. 7.
  #
  # @return [DNSSD::Service]
  #
  def service(name, protocol)
    proto = case protocol
            when :TCP
              "_tcp"
            when :UDP
              "_udp"
            else
              raise ArgumentError,
                "Invalid protocol (must be one of :TCP or :UDP)"
    end

    DNSSD::Service.new(Resolv::DNS::Name.new(["_#{name}", proto] + @domain.to_a))
  end

  # Create a new DNSSD::ServiceInstance.
  #
  # If you know everything about what you're trying to talk to except the
  # server list, you can go straight to the boss level with this method.
  #
  # @param name [String] the name of the service instance.
  #
  # @param service_name [String] the generic name of the service which the
  #   desired instance implements, *without* the leading underscore that
  #   is in the DNS name.
  #
  # @param service_protocol [Symbol] one of `:TCP` or `:UDP`.
  #
  # @return [DNSSD::ServiceInstance]
  #
  def service_instance(name, service_name, service_protocol)
    service(service_name, service_protocol).instance(name)
  end

  # Enumerate all known services in the domain.
  #
  # RFC6763 s. 9 provides a special "Service Type Enumeration" DNS record,
  # `_services._dns-sd._udp.<domain>`, which is a list of PTR records for
  # the services available in the domain.  If your DNS-SD registration system
  # provisions names in there, you can use this to enumerate the available
  # services.
  #
  # @return [Hash<String, DNSSD::Service>] the list of services, indexed by
  #   the service name.
  #
  def services
    {}.tap do |services|
      cached_resources(Resolv::DNS::Name.new(["_services", "_dns-sd", "_udp"] + @domain.to_a), Resolv::DNS::Resource::IN::PTR).each do |ptr|
        svc = DNSSD::Service.new(ptr.name)
        services[svc.name] = svc
      end
    end
  end
end
