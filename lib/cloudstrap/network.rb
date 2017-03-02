require 'ipaddress'
require_relative 'config'

module Cloudstrap
  class Network
    def initialize(network = '10.0.0.0')
      @network = IPAddress(network).tap { |n| n.prefix = 16 }
      self
    end

    attr_reader :network

    def subnets
      @subnets ||= network.subnet 24
    end

    def public
      @public ||= subnets.select { |subnet| subnet.octet(2).even? }
    end

    def private
      @private ||= subnets.select { |subnet| subnet.octet(2).odd? }
    end

    def public_layout(*zones)
      zones
        .zip(public.take(zones.size))
        .map { |zone, subnet| [zone, "#{subnet}/#{subnet.prefix}"] }
        .to_h
    end

    def private_layout(*zones)
      zones
        .zip(private.take(zones.size))
        .map { |zone, subnet| [zone, "#{subnet}/#{subnet.prefix}"] }
        .to_h
    end

    def layout(*zones)
      {
        public: public_layout(*zones),
        private: private_layout(*zones)
      }
    end

    private

    def config
      @config ||= Config.new
    end
  end
end
