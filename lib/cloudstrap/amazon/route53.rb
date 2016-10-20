require 'aws-sdk'
require 'contracts'
require_relative 'service'

module Cloudstrap
  module Amazon
    class Route53 < Service
      include ::Contracts::Core
      include ::Contracts::Builtin

      Contract None => ArrayOf[::Aws::Route53::Types::HostedZone]
      def zones
        @zones ||= zones!
      end

      Contract None => ArrayOf[::Aws::Route53::Types::HostedZone]
      def zones!
        @zones = call_api(:list_hosted_zones).hosted_zones
      end

      Contract String => Maybe[::Aws::Route53::Types::HostedZone]
      def zone(name)
        name = name.end_with?('.') ? name : name.dup.concat('.')

        zones.find { |zone| zone.name == name }
      end

      Contract String => Maybe[String]
      def longest_matching_suffix(name)
        candidates = {}
        name.split('.').reverse.reduce('') do |domain, fragment|
          [fragment, domain].join('.').tap do |suffix|
            candidates[suffix] = zones.select do |zone|
              zone.name == suffix
            end
          end
        end

        longest = candidates
          .reject { |_, zones| zones.empty? }
          .sort_by { |name, _| name.length }
          .last

        longest ? longest.first : nil
      end

      Contract String => Maybe[String]
      def zone_id(name)
        return unless zone = zone(name)

        zone(name).id.split('/').last
      end

      private

      def client
        ::Aws::Route53::Client
      end
    end
  end
end
