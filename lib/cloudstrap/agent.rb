require 'contracts'
require 'moneta'
require 'securerandom'

require_relative 'amazon'
require_relative 'config'
require_relative 'errors'
require_relative 'hcp/bootstrap_properties'
require_relative 'hooks'
require_relative 'network'
require_relative 'ssh'

module Cloudstrap
  class Agent
    include ::Contracts::Core
    include ::Contracts::Builtin
    include Hooks

    Contract None => Agent
    def initialize
      validate_configuration!
      self
    end

    Contract None => Any
    def validate_configuration!  # TODO: Does this really belong in Agent?
      return if ec2.valid_region?(config.region)
      raise ::Cloudstrap::ConfigurationError, "Region #{config.region} is not valid"
    end

    Contract None => String
    def create_vpc
      cache.store(:vpc_id, ec2.create_vpc.vpc_id).tap do |vpc_id|
        ec2.assign_name(bootstrap_tag, vpc_id)
      end
    end

    Contract None => Maybe[String]
    def find_vpc
      ENV.fetch('BOOTSTRAP_VPC_ID') do
        cache.fetch(:vpc_id) do
          cache.store :vpc_id, ec2
                               .tagged(type: 'vpc', value: bootstrap_tag)
                               .map(&:resource_id)
                               .first
        end
      end
    end

    Contract None => String
    def internet_gateway
      find_internet_gateway || create_internet_gateway
    end

    Contract None => String
    def create_internet_gateway
      cache.store(:internet_gateway_id,
                   ec2.create_internet_gateway.internet_gateway_id
                  ).tap { |internet_gateway_id| ec2.assign_name bootstrap_tag, internet_gateway_id }
    end

    Contract None => String
    def nat_gateway_ip_allocation
      ENV.fetch('BOOTSTRAP_NAT_GATEWAY_ALLOCATION_ID') do
        cache.fetch(:nat_gateway_allocation_id) do  # TODO: Simplify this.
          id = ec2
               .nat_gateways
               .select { |nat_gateway| nat_gateway.vpc_id == vpc }
               .flat_map { |nat_gateway| nat_gateway.nat_gateway_addresses.map { |address| address.allocation_id } }
               .first || ec2.unassociated_address || ec2.create_address
          cache.store(:nat_gateway_allocation_id, id)
        end
      end
    end

    Contract None => Maybe[String]
    def find_nat_gateway
      ec2
        .nat_gateways
        .select { |nat_gateway| nat_gateway.vpc_id == vpc }
        .reject { |nat_gateway| %w(failed deleted).include? nat_gateway.state }
        .map { |nat_gateway| nat_gateway.nat_gateway_id }
        .first
    end

    Contract None => String
    def create_nat_gateway
      attach_gateway unless ec2.internet_gateway_attached?(internet_gateway, vpc)
      ec2.create_nat_gateway(public_subnet, nat_gateway_ip_allocation).nat_gateway_id
    end

    Contract None => String
    def nat_gateway
      ENV.fetch('BOOTSTRAP_NAT_GATEWAY_ID') do
        cache.fetch(:nat_gateway_id) do
          cache.store(:nat_gateway_id, (find_nat_gateway || create_nat_gateway))
        end
      end
    end

    Contract None => Maybe[String]
    def find_internet_gateway
      ENV.fetch('BOOTSTRAP_INTERNET_GATEWAY_ID') do
        cache.fetch(:internet_gateway_id) do
          find_tagged_internet_gateway || find_internet_gateway_for_vpc
        end
      end
    end

    Contract None => Maybe[String]
    def find_tagged_internet_gateway
      ec2
        .tagged(type: 'internet-gateway', value: bootstrap_tag)
        .map { |resource| resource.resource.id }
        .first
    end

    Contract None => Maybe[String]
    def find_internet_gateway_for_vpc
      ec2
        .internet_gateways
        .select { |gateway| gateway.attachments.any? { |attachment| attachment.vpc_id == vpc } }
        .map { |gateway| gateway.internet_gateway_id }
        .first
    end

    Contract None => String
    def create_jumpbox_security_group
      cache.store(:jumpbox_security_group, ec2.create_security_group(:jumpbox, vpc)).tap do |sg|
        ec2.assign_name(bootstrap_tag, sg)
      end
    end

    Contract None => Maybe[String]
    def find_jumpbox_security_group
      @jumpbox_security_group ||= ENV.fetch('BOOTSTRAP_JUMPBOX_SECURITY_GROUP') do
        cache.fetch(:jumpbox_security_group) do
          cache.store :jumpbox_security_group, ec2
                                           .tagged(type: 'security-group', value: bootstrap_tag)
                                           .map(&:resource_id)
                                           .first
        end
      end
    end

    Contract None => Bool
    def allow_ssh
      ec2.authorize_security_group_ingress :tcp, 22, '0.0.0.0/0', jumpbox_security_group
    end

    Contract None => String
    def jumpbox_security_group
      find_jumpbox_security_group || create_jumpbox_security_group
    end

    Contract None => Network
    def network
      @network ||= Network.new config.vpc_cidr_block
    end

    Contract None => String
    def private_subnet
      private_subnets.values.first
    end

    Contract None => String
    def public_subnet
      public_subnets.values.first
    end

    Contract None => String
    def route_table
      @route_table ||= ENV.fetch('BOOTSTRAP_ROUTE_TABLE_ID') do
        cache.fetch(:route_table_id) do
          cache.store(:route_table_id, ec2
                                       .route_tables
                                       .select { |route_table| route_table.vpc_id == vpc }
                                       .select { |route_table| route_table.associations.any? { |association| association.main } }
                                       .map { |route_table| route_table.route_table_id }
                                       .first).tap do |route_table_id|
            ec2.assign_name bootstrap_tag, route_table_id
          end
        end
      end
    end

    Contract None => String
    def private_route_table
      @private_route_table ||= ENV.fetch('BOOTSTRAP_PRIVATE_ROUTE_TABLE_ID') do
        cache.fetch(:private_route_table_id) do
          id = ec2
               .route_tables
               .select { |route_table| route_table.vpc_id == vpc }
               .reject { |route_table| route_table.associations.any? { |association| association.main } }
               .map { |route_table| route_table.route_table_id }
               .first || ec2.create_route_table(vpc).route_table_id
          cache.store(:private_route_table_id, id).tap do |private_route_table_id|
            ec2.assign_name bootstrap_tag, private_route_table_id
          end
        end
      end
    end

    Contract None => Bool
    def attach_gateway
      ec2.attach_internet_gateway internet_gateway, vpc # TODO: Cache this
    end

    Contract None => Bool
    def default_route
      ec2.create_route('0.0.0.0/0', internet_gateway, route_table)  # TODO: Cache this
    end

    Contract None => Bool
    def nat_route
      ec2.create_route('0.0.0.0/0', nat_gateway, private_route_table)  # TODO: Cache this
    end

    Contract None => String
    def nat_route_association
      @nat_route_association || ENV.fetch('BOOTSTRAP_NAT_ROUTE_ASSOCIATION_ID') do
        cache.fetch(:nat_route_association_id) do
          cache.store(:nat_route_association_id, ec2.associate_route_table(private_route_table, private_subnet))
        end
      end
    end

    Contract None => HashOf[String, String]
    def public_subnets
      network.public_layout(*ec2.availability_zone_names).map do |az, cidr|
        properties = { vpc_id: vpc, cidr_block: cidr, availability_zone: az }
        subnet = ec2.subnet(properties) || ec2.create_subnet(properties)
        ec2.assign_name bootstrap_tag, subnet.subnet_id unless subnet
                                                                 .tags
                                                                 .any? do |tag|
          tag.key == 'Name' && tag.value == bootstrap_tag
        end
        [az, subnet.subnet_id]
      end.to_h
    end

    Contract None => ArrayOf[String]
    def subnets
      [public_subnet, private_subnet]
    end

    Contract None => HashOf[String, String]
    def private_subnets
      network.private_layout(*ec2.availability_zone_names).map do |az, cidr|
        properties = { vpc_id: vpc, cidr_block: cidr, availability_zone: az }
        subnet = ec2.subnet(properties) || ec2.create_subnet(properties)
        ec2.assign_name bootstrap_tag, subnet.subnet_id unless subnet
                                                                 .tags
                                                                 .any? do |tag|
          tag.key == 'Name' && tag.value == bootstrap_tag
        end
        [az, subnet.subnet_id]
      end.to_h
    end

    Contract None => Bool
    def enable_public_ips
      public_subnets.all? do |_, subnet|
        ec2.map_public_ip_on_launch?(subnet) || ec2.map_public_ip_on_launch(subnet, true)
      end
    end

    Contract None => Bool
    def configure_nat_routes
      private_subnets.all? do |_, subnet|
        ec2.associate_route_table private_route_table, subnet
      end
    end

    Contract None => String
    def vpc
      find_vpc || create_vpc
    end

    Contract None => Bool
    def enable_dns_support
      ec2.vpc_supports_dns?(vpc) || ec2.enable_dns_support(vpc)
    end

    Contract None => Bool
    def enable_dns_hostnames
      ec2.vpc_supports_dns_hostnames?(vpc) || ec2.enable_dns_hostnames(vpc)
    end

    Contract None => String
    def create_jumpbox
      upload_ssh_key

     cache.store(:jumpbox_id, ec2.create_instance(
                   image_id: ami,
                   instance_type: config.instance_type,
                   key_name: bootstrap_tag,
                   client_token: Digest::SHA256.hexdigest(bootstrap_tag),
                   network_interfaces: [{
                                          device_index: 0,
                                          subnet_id: public_subnet,
                                          associate_public_ip_address: true,
                                          groups: [jumpbox_security_group]
                                        }]
                 ).instance_id).tap do |instance_id|
       ec2.assign_name bootstrap_tag, instance_id
     end
    end

    Contract None => Maybe[String]
    def find_jumpbox
      ENV.fetch('BOOTSTRAP_JUMPBOX_ID') do
        cache.fetch(:jumpbox_id) do
          ec2
            .tagged(type: 'instance', value: bootstrap_tag)
            .map(&:resource_id)
            .first
        end
      end
    end

    Contract None => String
    def jumpbox
      find_jumpbox || create_jumpbox
    end

    Contract None => Bool
    def tag_jumpbox
      ec2.create_tags([jumpbox], [{ key: 'Cloudstrapped', value: 'true' }])
    end

    Contract None => String
    def ami
      @ami ||= ENV.fetch('BOOTSTRAP_AMI') do
        cache.fetch(:ami_id) do
          cache.store :ami_id, ec2.latest_ubuntu(config.ubuntu_release).image_id
        end
      end
    end

    Contract None => String
    def upload_ssh_key
      ec2.import_key_pair bootstrap_tag, ssh_key.to_s # TODO: Cache this.
    end

    Contract None => SSH::Key
    def ssh_key
      @ssh_key ||= SSH::Key.new bootstrap_tag
    end

    Contract None => String
    def bootstrap_tag
      @bootstrap_tag ||= ENV.fetch('BOOTSTRAP_TAG') do
        "lkg@#{username}/#{uuid}"
      end
    end

    Contract None => String
    def username
      @username ||= ENV.fetch('BOOTSTRAP_USERNAME') do
        cache.fetch(:username) do
          cache.store(:username, iam.user.user_name)
        end
      end
    end

    Contract None => String
    def uuid
      @uuid ||= ENV.fetch('BOOTSTRAP_UUID') do
        cache.fetch(:uuid) do
          cache.store(:uuid, SecureRandom.uuid)
        end
      end
    end

    Contract None => String
    def public_availability_zone
      public_subnets.keys.first
    end

    Contract None => String
    def private_availability_zone
      private_subnets.keys.first
    end

    Contract None => String
    def jumpbox_ip
      @jumpbox_ip ||= ENV.fetch('BOOTSTRAP_JUMPBOX_IP') do
        cache.fetch(:jumpbox_ip) do
          cache.store(:jumpbox_ip, ec2
                                   .instances
                                   .select { |instance| instance.instance_id == jumpbox }
                                   .flat_map(&:network_interfaces)
                                   .map(&:association)
                                   .map(&:public_ip)
                                   .first)
        end
      end
    end

    Contract None => Bool
    def configure_hcp
      bootstrap_properties
        .define('Provider', 'AWS')
        .define('KeepTerraform', 'true')
        .define('AWS.NodeInstanceType', config.node_instance_type)
        .define('AWS.MasterInstanceType', config.master_instance_type)
        .define('AWS.GlusterFSInstanceType', config.gluster_instance_type)
        .define('NodeCount', config.node_count)
        .define('MasterCount', config.master_count)
        .define('GlusterNodeCount', config.gluster_count)
        .define('AWS.Region', config.region)
        .define('AWS.AvailabilityZones', ec2.availability_zone_names.join(','))
        .define('AWS.PublicSubnetIDsAndAZ', public_subnets.invert.map { |*s| s.join(':') }.join(','))
        .define('AWS.PrivateSubnetIDsAndAZ', private_subnets.invert.map { |*s| s.join(':') }.join(','))
        .define('AWS.Keypair', bootstrap_tag)
        .define('AWS.KeypairFile', '/home/ubuntu/.ssh/id_rsa')
        .define('AWS.JumpboxCIDR', '0.0.0.0/0')
        .define('AWS.VPCID', vpc)
        .define('AWS.LinuxAMI', ami)
        .define('HCPDomainName', config.domain_name)
        .save!
    end

    Contract None => Bool
    def jumpbox_running?
      ec2
        .instances
        .select { |instance| instance.instance_id == jumpbox }
        .map { |instance| instance.state.name }
        .first == 'running'
    end

    Contract None => Any
    def configure_jumpbox
      private_key = ssh_key.private_file
      properties = bootstrap_properties.file
      package = config.hcp_package_url

      hooking(:setup) do
        ssh.to(jumpbox_ip).each do
          '/home/ubuntu/.ssh/id_rsa'.tap do |target|
            execute :rm, '-f', target
            upload! private_key, target
            execute :chmod, '-w', target
          end

          upload! properties, '/home/ubuntu/bootstrap.properties'

          as :root do
            execute :apt, *%w(install --assume-yes genisoimage aria2)
            execute :rm, '-f', '/opt/bootstrap.deb'
            execute :aria2c, '--continue=true', '--dir=/opt', '--out=bootstrap.deb', package
            execute :dpkg, *%w(--install /opt/bootstrap.deb)
          end
        end
      end
    end

    Contract None => Bool
    def requires_human_oversight?
      ['false', 'nil', nil].include? ENV['BOOTSTRAP_WITHOUT_HUMAN_OVERSIGHT']
    end

    Contract None => Any
    def launch
      return false if requires_human_oversight?

      access_key_id = ec2.api.config.credentials.credentials.access_key_id
      secret_access_key = ec2.api.config.credentials.credentials.secret_access_key

      ssh.to(jumpbox_ip) do
        with(aws_access_key_id: access_key_id, aws_secret_access_key: secret_access_key) do
          execute :bootstrap, *%w(install bootstrap.properties)
        end
      end
    end

    private

    Contract None => SSH::Client
    def ssh
      @ssh ||= SSH::Client.new(ssh_key.private_file)
    end

    Contract None => HCP::BootstrapProperties
    def bootstrap_properties
      @hcp ||= HCP::BootstrapProperties.new
    end

    Contract None => Amazon::EC2
    def ec2
      @ec2 ||= Amazon::EC2.new
    end

    Contract None => Amazon::IAM
    def iam
      @iam ||= Amazon::IAM.new
    end

    Contract None => Config
    def config
      @config ||= Config.new
    end

    Contract RespondTo[:to_s] => Maybe[Any]
    def environment(variable)
      ENV.fetch("#{config.environment_namespace}_#{variable.to_s.upcase}") do
        yield if block_given?
      end
    end

    Contract None => Moneta::Proxy
    def cache
      @cache ||= Moneta.new :File, dir: config.cache_path
    end
  end
end
