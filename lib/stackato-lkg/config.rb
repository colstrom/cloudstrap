require 'contracts'
require 'yaml'

module StackatoLKG
  class Config
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract None => String
    def region
      @region ||= ENV.fetch('BOOTSTRAP_REGION') { config.fetch('region') }
    end

    Contract None => String
    def cache_path
      @cache_path ||= ENV.fetch('BOOTSTRAP_CACHE_PATH') do
        config.fetch('cache_path') { [workdir, '.cache'].join('/') }
      end
    end

    Contract None => String
    def vpc_cidr_block
      @vpc_cidr_block ||= ENV.fetch('BOOTSTRAP_VPC_CIDR_BLOCK') do
        config.fetch('vpc_cidr_block') { '10.0.0.0/16' }
      end
    end

    Contract None => String
    def public_cidr_block
      @public_cidr_block ||= ENV.fetch('BOOTSTRAP_PUBLIC_CIDR_BLOCK') do
        config.fetch('public_cidr_block') do
          vpc_cidr_block.gsub(/([[:digit:]]{1,3}\.?){2,2}\/[[:digit:]]{1,2}$/, '0.0/24')
        end
      end
    end

    Contract None => String
    def private_cidr_block
      @private_cidr_block ||= ENV.fetch('BOOTSTRAP_PRIVATE_CIDR_BLOCK') do
        config.fetch('private_cidr_block') do
          vpc_cidr_block.gsub(/([[:digit:]]{1,3}\.?){2,2}\/[[:digit:]]{1,2}$/, '1.0/24')
        end
      end
    end

    Contract None => String
    def ami_owner
      @ami_owner ||= ENV.fetch('BOOTSTRAP_AMI_OWNER') do
        config.fetch('ami_owner') do
          '099720109477'
        end
      end
    end

    Contract None => String
    def ubuntu_release
      @distribution ||= ENV.fetch('BOOTSTRAP_UBUNTU_RELEASE') do
        config.fetch('ubuntu_release') do
          '14.04'
        end
      end
    end

    Contract None => String
    def ssh_dir
      @ssh_dir ||= File.expand_path(ENV.fetch('BOOTSTRAP_SSH_DIR') do
        [workdir, '.ssh'].join('/')
      end)
    end

    private

    Contract None => String
    def workdir
      @workdir ||= ENV.fetch('BOOTSTRAP_WORKDIR') { Dir.pwd }
    end

    Contract None => String
    def dir
      @dir ||= ENV.fetch('BOOTSTRAP_CONFIG_DIR') { workdir }
    end

    Contract None => String
    def file
      @file ||= ENV.fetch('BOOTSTRAP_CONFIG_FILE') { 'config.yaml' }
    end

    Contract None => String
    def path
      @path ||= File.expand_path [dir, file].join('/')
    end

    Contract None => Hash
    def config
      @settings ||= if File.exist?(path)
                      YAML.load_file(path)
                    else
                      raise ::Errno::ENOENT, path
                      {}
                    end
    end
  end
end
