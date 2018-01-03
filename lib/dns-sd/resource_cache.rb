require 'resolv'

class DNSSD
  # A mix-in to provide a TTL-respecting caching layer.
  module ResourceCache
    private

    # Return a list of resource records.
    #
    # We'll ask the DNS, via `Resolv::DNS`, for DNS records matching the
    # given FQDN and type, unless we've recently seen a response for the
    # same query, in which case we'll just give that back instead.
    #
    # Note that we don't currently implement negative caching, but it's
    # not a massive optimisation for our use-case, anyway.
    #
    # @param fqdn [Resolv::DNS::Name] the name to look up resources at.
    #
    # @param type [Resolv::DNS::Resource] the type of resource to request.
    #
    # @return [Array<Resolv::DNS::Resource>]
    #
    def cached_resources(fqdn, type)
      @rrcache ||= {}

      k = [fqdn, type]

      if @rrcache[k] && @rrcache[k][:expiry] > Time.now
        @rrcache[k][:records].dup
      else
        Resolv::DNS.new.getresources(fqdn, type).tap do |rrs|
          if rrs.empty?
            @rrcache.delete(k)
          else
            @rrcache[k] = { records: rrs.dup, expiry: Time.now + rrs.map { |rr| rr.ttl }.min }
          end
        end
      end
    end

    def entry_expiry_time(fqdn, type)
      k = [fqdn, type]

      if @rrcache && @rrcache[k]
        @rrcache[k][:expiry].dup
      else
        nil
      end
    end
  end
end
