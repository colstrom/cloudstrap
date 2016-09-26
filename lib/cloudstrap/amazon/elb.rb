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

      Contract None => ArrayOf[String]
      def names
        list.map(&:load_balancer_name)
      end

      Tags = HashOf[String, String]

      Contract None => HashOf[String, Tags]
      def tags
        @tags ||= tags!
      end

      Contract None => HashOf[String, Tags]
      def tags!
        @tags = names.each_slice(20).flat_map do |slice|
          tags(slice)
        end.reduce(&:merge)
      end

      Contract ArrayOf[String] => HashOf[String, Tags]
      def tags(elb_names)
        describe_tags(*elb_names).each_with_object({}) do |description, hash|
          hash[description.load_balancer_name] = description
                                                   .tags
                                                   .map(&:to_a)
                                                   .to_h
        end
      end

      Contract String => HashOf[String, ::Aws::ElasticLoadBalancing::Types::LoadBalancerDescription]
      def tagged(key)
        tags.map do |name, tags|
          next unless tags[key]
          { tags[key] => list.find { |elb| elb.load_balancer_name == name } }
        end.compact.reduce(&:merge)
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
