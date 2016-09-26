require 'aws-sdk'
require 'contracts'
require_relative 'service'

module Cloudstrap
  module Amazon
    class Route53 < Service
      include ::Contracts::Core
      include ::Contracts::Builtin

      private

      def client
        ::Aws::Route53::Client
      end
    end
  end
end
