require 'contracts'
require 'moneta'
require 'securerandom'

require_relative 'amazon'
require_relative 'config'

module StackatoLKG
  class BootstrapAgent
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract None => String
    def create_vpc
      cache.store(:vpc_id, ec2.create_vpc.vpc_id).tap do |vpc_id|
        ec2.assign_name(tag, vpc_id)
      end
    end

    Contract None => Maybe[String]
    def find_vpc
      ENV.fetch('BOOTSTRAP_VPC_ID') do
        cache.fetch(:vpc_id) do
          cache.store :vpc_id, ec2
                               .tagged(type: 'vpc', value: tag)
                               .map(&:resource_id)
                               .first
        end
      end
    end

    Contract None => String
    def create_jumpbox_security_group
      cache.store(:jumpbox_security_group, ec2.create_security_group(:jumpbox, vpc)).tap do |sg|
        ec2.assign_name(tag, sg)
      end
    end

    Contract None => Maybe[String]
    def find_jumpbox_security_group
      @jumpbox_security_group ||= ENV.fetch('BOOTSTRAP_JUMPBOX_SECURITY_GROUP') do
        cache.fetch(:jumpbox_security_group) do
          cache.store :jumpbox_security_group, ec2
                                           .tagged(type: 'security-group', value: tag)
                                           .map(&:resource_id)
                                           .first
        end
      end
    end

    Contract None => String
    def jumpbox_security_group
      find_jumpbox_security_group || create_jumpbox_security_group
    end

    Contract None => String
    def vpc
      find_vpc || create_vpc
    end

    Contract None => String
    def tag
      @tag ||= ENV.fetch('BOOTSTRAP_TAG') do
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

    private

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

    Contract None => Moneta::Proxy
    def cache
      @cache ||= Moneta.new :File, dir: config.cache_path
    end
  end
end
