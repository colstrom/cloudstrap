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

      Contract None => ArrayOf[::Aws::EC2::Types::RouteTable]
      def route_tables
        @route_tables ||= route_tables!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::RouteTable]
      def route_tables!
        @route_tables ||= call_api(:describe_route_tables).route_tables
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

      Contract None => ArrayOf[::Aws::EC2::Types::SecurityGroup]
      def security_groups
        @security_groups ||= security_groups!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::SecurityGroup]
      def security_groups!
        @security_groups = call_api(:describe_security_groups).security_groups
      end

      Contract None => ArrayOf[::Aws::EC2::Types::TagDescription]
      def tags
        @tags ||= tags!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::TagDescription]
      def tags!
        @tags = call_api(:describe_tags).tags
      end

      Contract KeywordArgs[
                 image_id: String,
                 instance_type: String,
                 key_name: Optional[String],
                 client_token: Optional[String],
                 network_interfaces: Optional[ArrayOf[Hash]]
               ] => ::Aws::EC2::Types::Instance
      def create_instance(**properties)
        call_api(:run_instances, properties.merge(min_count: 1, max_count: 2)).instances.first
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Image]
      def images
        @images ||= images!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::Image]
      def images!
        @images ||= call_api(:describe_images,
                             owners: [config.ami_owner],
                             filters: [
                               { name: 'virtualization-type', values: ['hvm'] },
                               { name: 'architecture', values: ['x86_64'] },
                               { name: 'root-device-type', values: ['ebs'] },
                               { name: 'block-device-mapping.volume-type', values: ['gp2'] }
                             ])
                  .images
                  .reject { |image| image.sriov_net_support.nil? }
      end

      Contract RespondTo[:to_s] => ArrayOf[::Aws::EC2::Types::Image]
      def ubuntu_images(release)
        images
          .select { |image| image.name.start_with? 'ubuntu/images/' }
          .select { |image| image.name.include? release.to_s }
      end

      Contract RespondTo[:to_s] => ::Aws::EC2::Types::Image
      def latest_ubuntu(release)
        ubuntu_images(release)
          .sort_by { |image| image.creation_date }
          .last
      end

      Contract None => ArrayOf[::Aws::EC2::Types::KeyPairInfo]
      def key_pairs
        @key_pairs ||= key_pairs!
      end

      Contract None => ArrayOf[::Aws::EC2::Types::KeyPairInfo]
      def key_pairs!
        @key_pairs = call_api(:describe_key_pairs).key_pairs
      end

      Contract String => Maybe[String]
      def key_fingerprint(key_name)
        key_pairs
          .select { |ssh| ssh.key_name == key_name }
          .map { |ssh| ssh.key_fingerprint }
          .first
      end

      Contract String, String => String
      def import_key_pair(key_name, public_key_material)
        call_api(:import_key_pair, key_name: key_name, public_key_material: public_key_material).key_fingerprint
      rescue ::Aws::EC2::Errors::InvalidKeyPairDuplicate
        key_fingerprint(key_name)
      end

      Contract None => ::Aws::EC2::Types::Vpc
      def create_vpc
        call_api(:create_vpc, cidr_block: config.vpc_cidr_block).vpc
      end

      Contract KeywordArgs[
                 cidr_block: Optional[String],
                 vpc_id: Optional[String],
                 subnet_id: Optional[String]
               ] => ArrayOf[::Aws::EC2::Types::Subnet]
      def subnets(cidr_block: nil, vpc_id: nil, subnet_id: nil)
        subnets
          .select { |subnet| subnet_id.nil? || subnet.subnet_id == subnet_id }
          .select { |subnet| vpc_id.nil? || subnet.vpc_id == vpc_id }
          .select { |subnet| cidr_block.nil? || subnet.cidr_block == cidr_block }
      end

      Contract Args[Any] => Any
      def subnets!(**properties)
        subnets!
        subnets(properties)
      end

      Contract Args[Any] => Maybe[::Aws::EC2::Types::Subnet]
      def subnet(**properties)
        subnets(properties).first
      end

      Contract Args[Any] => Any
      def subnet!(**properties)
        subnets!
        subnet(properties)
      end

      Contract KeywordArgs[
                 cidr_block: String,
                 vpc_id: String
               ] => ::Aws::EC2::Types::Subnet
      def create_subnet(**properties)
        call_api(:create_subnet, properties).subnet
      rescue ::Aws::EC2::Errors::InvalidSubnetConflict
        subnet(properties) || subnet!(properties)
      end

      Contract String => Bool
      def map_public_ip_on_launch?(subnet_id)
        subnets(subnet_id: subnet_id)
          .map { |subnet| subnet.map_public_ip_on_launch }
          .first == true
      end

      Contract String, Bool => Bool
      def map_public_ip_on_launch(subnet_id, value)
        call_api(:modify_subnet_attribute,
                 subnet_id: subnet_id,
                 map_public_ip_on_launch: { value: value }
                ).successful?
      end

      Contract RespondTo[:to_s], RespondTo[:to_i], RespondTo[:to_s], String => Bool
      def authorize_security_group_ingress(ip_protocol, port, cidr_ip, group_id)
        call_api(:authorize_security_group_ingress,
                 group_id: group_id,
                 ip_protocol: ip_protocol.to_s,
                 from_port: port.to_i,
                 to_port: port.to_i,
                 cidr_ip: cidr_ip.to_s
                ).successful?
      rescue ::Aws::EC2::Errors::InvalidPermissionDuplicate
        true
      end

      Contract RespondTo[:to_s], String => String
      def create_security_group(group_name, vpc_id)
        call_api(:create_security_group,
                 group_name: group_name.to_s,
                 description: group_name.to_s,
                 vpc_id: vpc_id).group_id
      rescue ::Aws::EC2::Errors::InvalidGroupDuplicate
        security_group(group_name.to_s, vpc_id)
      end

      Contract RespondTo[:to_s], String => String
      def security_group(group_name, vpc_id)
        security_groups
          .select { |sg| sg.vpc_id == vpc_id }
          .select { |sg| sg.group_name == group_name }
          .first
          .group_id
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
