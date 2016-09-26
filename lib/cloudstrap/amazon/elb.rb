require 'aws-sdk'
require 'contracts'
require_relative 'service'

module Cloudstrap
  module Amazon
    class ELB < Service
      include ::Contracts::Core
      include ::Contracts::Builtin

      Contract None => ArrayOf[::Aws::ElasticLoadBalancing::Types::LoadBalancerDescription]
      def list
        @list ||= list!
      end

      Contract None => ArrayOf[::Aws::ElasticLoadBalancing::Types::LoadBalancerDescription]
      def list!
        @list = call_api(:describe_load_balancers).load_balancer_descriptions
      end

      private

      def client
        ::Aws::ElasticLoadBalancing::Client
      end
    end
  end
end
