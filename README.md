[DNS-SD](https://tools.ietf.org/html/rfc6763) is a method of laying out
standard DNS records in such a way that permits service discovery and
enumeration, high availability, load balancing, and failover of arbitrary
services.  Whilst it is often used in concert with [Multicast DNS
(mDNS)](https://tools.ietf.org/html/rfc67621), it works just as well with
regular DNS services, and that is what this package is focused on.  If
you're interested in mDNS-based DNS-SD interaction, the [similarly-named
dnssd gem](https://rubygems.org/gems/dnssd) might be more to your liking.


# Installation

It's a gem:

    gem install dns-sd

There's also the wonders of [the Gemfile](http://bundler.io):

    gem 'dns-sd'

If you're the sturdy type that likes to run from git:

    rake install

Or, if you've eschewed the convenience of Rubygems entirely, then you
presumably know what to do already.


# Usage

The basic class, DNSSD, is the usual entrypoint for everything:

    require 'dns-sd'

    dnssd = DNSSD.new("example.com")

From there, you can connect directly to a service instance, get a service
type so you can ask it for all available instances, or even ask for all
services in the domain.

The sub-sections below show some common usage patterns.  If your specific
use case isn't covered, the per-class documentation may be more
enlightening.


## Connecting to a service instance

If you know what service and instance you're interested in, you can go
straight there:

    my_printer = dnssd.service_instance("My Printer", "ipp", :TCP)

Then get the connection targets and even try connecting to them:

    targets = my_printer.targets

    sock = begin
      break nil if targets.empty?
      t = targets.shift
      TCPSocket.new(t.hostname, t.port)
    rescue SystemCallError
      # Automatically go on to the next server
      retry
    end

    if sock.nil?
      $stderr.puts "Failed to connect to My Printer"
    else
      # Work with `sock` as required
    end

If there's more than one target registered for a given service instance
(common in high-availability and load-balanced systems), every time you call
DNSSD::ServiceInstance#targets, you'll get the server list in a different
order, respecting the priorities and weights of the constituent SRV records.

The SRV record lookups (like all DNS records) are cached, so if you wish
to connect to a service instance repeatedly, you should call #targets on
your service instance object each time you want to make a connection, rather
than re-using the result of a single call to #target.  As long as you're
operating against the same DNSSD::ServiceInstance object and the record TTLs
haven't expired, successive calls to #target should be very efficient.


## Enumerating all instances of a service

If you know you want a printer, but aren't sure which one, you can ask for
the IPP service, and then enumerate all the service instances:

    dnssd.service("ipp", :TCP).each do |name, instance|
      puts "I found a printer named #{name}"
      puts "Its targets are #{instance.targets.map { |t| "#{t.hostname}:#{t.port}" }.join(", ")}"
    end

## Enumerating all services

If you're just curious about what might be on a domain, you can try the
"Service Type Enumeration" endpoint:

    dnssd.services.each do |name, svc|
      puts "I found a service named #{name}"
      puts "It has instances of #{svc.instances.map { |i| i.name }.join(", ")}"
    end


# Contributing

Bug reports should be sent to the [Github issue
tracker](https://github.com/discourse/dns-sd/issues).  Patches can be sent as a
[Github pull request](https://github.com/discourse/dns-sd/pulls).


# Licence

Unless otherwise stated, everything in this repo is covered by the following
copyright notice:

    Copyright (C) 2017, 2019 Civilized Discourse Construction Kit, Inc.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
