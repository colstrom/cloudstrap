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

      private

      def client
        ::Aws::Route53::Client
      end
    end
  end
end
