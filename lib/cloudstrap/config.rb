require 'contracts'
require 'pastel'
require 'yaml'

module StackatoLKG
  class Config
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract None => String
    def region
      @region ||= ENV.fetch('BOOTSTRAP_REGION') do
        config.fetch('region') do
          'us-west-2'
        end
      end
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
    def instance_type
      @instance_type ||= ENV.fetch('BOOTSTRAP_INSTANCE_TYPE') do
        config.fetch('instance_type') do
          't2.micro'
        end
      end
    end

    Contract None => String
    def ssh_dir
      @ssh_dir ||= File.expand_path(ENV.fetch('BOOTSTRAP_SSH_DIR') do
        [workdir, '.ssh'].join('/')
      end)
    end

    Contract None => String
    def ssh_username
      @ssh_username ||= ENV.fetch('BOOTSTRAP_SSH_USERNAME') do
        config.fetch('ssh_username') do
          'ubuntu'
        end
      end
    end

    Contract None => String
    def hdp_dir
      @hdp_dir ||= File.expand_path(ENV.fetch('BOOTSTRAP_HDP_DIR') { dir })
    end

    Contract None => String
    def hdp_origin
      @hdp_origin ||= ENV.fetch('BOOTSTRAP_HDP_BOOTSTRAP_ORIGIN') do
        config.fetch('hdp_bootstrap_origin') do
          'https://s3-us-west-2.amazonaws.com/hcp-concourse'
        end
      end
    end

    Contract None => String
    def hdp_version
      @hdp_archive ||= ENV.fetch('BOOTSTRAP_HDP_BOOTSTRAP_VERSION') do
        config.fetch('hdp_bootstrap_version') do  # TODO: Output colorization should be defined elsewhere.
          STDERR.puts Pastel.new.yellow '# No version specified for HDP Bootstrap, falling back to default version'
          '1.2.30+master.77bb464.20160819000448'
        end
      end
    end

    Contract None => String
    def hdp_package_url
      @hdp_package_url ||= ENV.fetch('BOOTSTRAP_HDP_BOOTSTRAP_PACKAGE_URL') do
        config.fetch('hdp_bootstrap_package_url') do
          "#{hdp_origin}/hcp-bootstrap_#{hdp_version.gsub('+', '%2B')}_amd64.deb"
        end
      end
    end

    Contract None => String
    def bootstrap_properties_seed_url
      ENV.fetch('BOOTSTRAP_PROPERTIES_SEED_URL') do
        config.fetch('bootstrap_properties_seed_url') do
          'https://s3.amazonaws.com/cnap/alvaro/hdp-resource-manager-0-1-28/bootstrap/sample_bootstrap.properties'
        end
      end
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
                      {}
                    end
    end
  end
end
