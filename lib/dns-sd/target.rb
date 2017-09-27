class DNSSD
  # A representation of a SRV record target.
  #
  # This is the end result of pretty much everything you want to get out of
  # service discovery: a hostname to resolve, and a port to connect to.
  Target = Struct.new(:hostname, :port)
end
