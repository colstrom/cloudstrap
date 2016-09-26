require 'aws-sdk'
require 'contracts'
require_relative 'service'

module Cloudstrap
  module Amazon
    class ELB < Service
      include ::Contracts::Core
      include ::Contracts::Builtin

      private

      def client
        ::Aws::ElasticLoadBalancing::Client
      end
    end
  end
end
