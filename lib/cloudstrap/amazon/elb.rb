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

      Tags = HashOf[String, String]

      Contract Args[String] => HashOf[String, Tags]
      def tags(*elb_names)
        describe_tags(*elb_names).each_with_object({}) do |description, hash|
          hash[description.load_balancer_name] = description
                                                   .tags
                                                   .map(&:to_a)
                                                   .to_h
        end
      end

      private

      Contract Args[String] => ArrayOf[::Aws::ElasticLoadBalancing::Types::TagDescription]
      def describe_tags(*elb_names)
        call_api(:describe_tags, load_balancer_names: elb_names).tag_descriptions
      end

      def client
        ::Aws::ElasticLoadBalancing::Client
      end
    end
  end
end
