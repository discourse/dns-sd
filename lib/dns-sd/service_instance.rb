require 'dns-sd/resource_cache'
require 'dns-sd/service'
require 'dns-sd/target'

require 'resolv'

class DNSSD
  # A single instance of a service.
  #
  # This is where the rubber hits the road: servers to talk to, and instance
  # metadata, is all under here.
  #
  class ServiceInstance
    include DNSSD::ResourceCache

    # The name of this service instance.
    #
    # This is just the left-most component of the service instance FQDN, and
    # can, as such, contain practically anything at all.
    #
    # @return [String]
    #
    attr_reader :name

    # The FQDN of this service instance.
    #
    # @return [Resolv::DNS::Name]
    #
    attr_reader :fqdn

    # The generic service which this instance implements.
    #
    # If you happen to forget what protocol to use, this might come in
    # handy.
    #
    # @return [DNSSD::Service]
    #
    attr_reader :service

    # Create the service instance.
    #
    # @param fqdn [Resolv::DNS::Name]
    #
    def initialize(fqdn)
      unless fqdn.is_a?(Resolv::DNS::Name)
        raise ArgumentError,
          "FQDN must be a Resolv::DNS::Name (got an instance of #{fqdn.class})"
      end

      @fqdn = fqdn

      @name = fqdn[0].to_s
      @service = DNSSD::Service.new(Resolv::DNS::Name.new(fqdn[1..-1]))
    end

    # Return the metadata for the service instance.
    #
    # RFC6763 s. 6 describes a means by which specially formatted TXT records
    # can be used to provide metadata for a service instance.  If your
    # services populate such data, you can access it here.
    #
    # @return [Hash<String, String or nil>] the key-value metadata, presented
    #   as a nice hash for your looking-up convenience.  If your metadata
    #   contains "Attribute present, with no value" tags, then the value of
    #   the associated key will be `nil`, whereas "Attribute present, with
    #   empty value" will have a value of the empty string (`""`).
    #
    def data
      {}.tap do |data|
        cached_resources(@fqdn, Resolv::DNS::Resource::IN::TXT).each do |rr|
          rr.strings.each do |s|
            if s =~ /\A([^=]+)(=(.*))?$/
              data[$1.to_sym] = $3
            end
          end
        end
      end
    end

    # The things to connect to for this service instance.
    #
    # This is what you're here for, I'll bet.  Everything comes down to this.
    # Each DNSSD::Target object in this list contains an FQDN (`#hostname`) and
    # port (`#port`) to connect to, which you can walk in order in order to
    # get to something that will talk to you.
    #
    # Every time you call this method, even if the records are cached, you may
    # get the targets in a different order.  This is because we automatically
    # sort the list of targets according to the rules for SRV record priority
    # and weight.  Thus, it is recommended that every time you want to make a
    # connection to the service instance, you call `#targets` again, both
    # because the DNS records may have expired (and thus will be re-queried),
    # but also because it'll ensure that the weight-based randomisation of the
    # server list is respected.
    #
    # @return [Array<DNSSD::Target>]
    def targets
      [].tap do |list|
        left = cached_resources(@fqdn, Resolv::DNS::Resource::IN::SRV)

        # Happily, this algorithm, whilst a bit involved, maps quite directly
        # to the description from RFC2782, page 4, of which parts are quoted as
        # appropriate below.  A practical example of how this process runs is
        # described in the test suite, also, which might help explain what's
        # happening.
        #
        # > This process is repeated for each Priority.
        until left.empty?
          # > A client MUST attempt to contact the target host with the
          # > lowest-numbered priority it can reach; target hosts with the
          # > same priority SHOULD be tried in an order defined by the weight
          # > field.
          prio = left.map { |rr| rr.priority }.uniq.min

          # > The following algorithm SHOULD be used to order the SRV RRs of the
          # > same priority:
          candidates = left.select { |rr| rr.priority == prio }
          left -= candidates

          # > arrange all SRV RRs (that have not been ordered yet) in any
          # > order, except that all those with weight 0 are placed at the
          # > beginning of the list.
          #
          # Because it makes it easier to test, I like to sort by weight and
          # name (<lawyer>it counts as "any order"</lawyer>).  This does mean
          # that all the zero-weight entries come back in name order, but
          # if you don't want that behaviour, it's easy enough to give
          # everything weight=1 and they'll be properly randomised.
          candidates.sort_by! { |rr| [rr.weight, rr.target.to_s] }

          # > Continue the ordering process until there are no unordered SRV
          # > RRs.
          until candidates.empty?
            # > Compute the sum of the weights of those RRs, and with each RR
            # > associate the running sum in the selected order. Then choose a
            # > uniform random number between 0 and the sum computed
            # > (inclusive)
            selector = rand(candidates.inject(1) { |n, rr| n + rr.weight })

            # > select the RR whose running sum value is the first in the
            # > selected order which is greater than or equal to the random
            # > number selected
            chosen = candidates.inject(0) do |n, rr|
              break rr if n + rr.weight >= selector
              n + rr.weight
            end
            # > Remove this SRV RR from the set of the unordered SRV RRs
            candidates.delete(chosen)
            list << DNSSD::Target.new(chosen.target.to_s, chosen.port)
          end
        end
      end
    end
  end
end
