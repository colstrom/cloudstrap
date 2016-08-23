require 'aws-sdk'
require 'contracts'
require_relative 'service'

module StackatoLKG
  module Amazon
    class EC2 < Service
      Contract None => ArrayOf[::Aws::EC2::Types::Vpc]
      def vpcs
        @vpcs ||= vpcs!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Vpc]
      def vpcs!
        @vpcs = call_api(:describe_vpcs).vpcs
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Subnet]
      def subnets
        @subnets ||= subnets!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Subnet]
      def subnets!
        @subnets = call_api(:describe_subnets).subnets
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Instance]
      def instances
        @instances ||= instances!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Instance]
      def instances!
        @instances = call_api(:describe_instances)
                     .reservations
                     .flat_map(&:instances)
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Address]
      def addresses
        @addresses ||= addresses!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Address]
      def addresses!
        @addresses = call_api(:describe_addresses).addresses
      end

      Contract None => ArrayOf[::Aws::EC2::Types::TagDescription]
      def tags
        @tags ||= tags!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::TagDescription]
      def tags!
        @tags = call_api(:describe_tags).tags
      end

      Contract None => ::Aws::EC2::Types::Vpc
      def create_vpc
        call_api(:create_vpc, cidr_block: config.cidr_block).vpc
      end

      Contract ArrayOf[String], ArrayOf[{ key: String, value: String}] => Bool
      def create_tags(resources, tags)
        call_api(:create_tags, resources: resources, tags: tags).successful?
      end

      Contract String, Args[String] => Bool
      def assign_name(name, *resources)
        create_tags(resources, [{ key: 'Name', value: name } ])
      end

      Contract KeywordArgs[
                 type: Optional[String],
                 key: Optional[String],
                 value: Optional[String]
               ] => ArrayOf[::Aws::EC2::Types::TagDescription]
      def tagged(type: nil, key: nil, value: nil)
        tags
          .select { |tag| type.nil? || tag.resource_type == type }
          .select { |tag| tag.key == (key || 'Name') }
          .select { |tag| value.nil? || tag.value == value }
      end

      private

      def client
        Aws::EC2::Client
      end
    end
  end
end
