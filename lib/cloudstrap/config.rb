require 'contracts'
require 'pastel'
require 'yaml'

module StackatoLKG
  class Config
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract None => String
    def region
      lookup(:region) { 'us-west-2' }
    end

    Contract None => String
    def cache_path
      lookup(:cache_path) { [workdir, '.cache'].join('/') }
    end

    Contract None => String
    def vpc_cidr_block
      lookup(:vpc_cidr_block) { '10.0.0.0/16' }
    end

    Contract None => String
    def public_cidr_block
      lookup(:public_cidr_block) do
        vpc_cidr_block.gsub(/([[:digit:]]{1,3}\.?){2,2}\/[[:digit:]]{1,2}$/, '0.0/24')
      end
    end

    Contract None => String
    def private_cidr_block
      lookup(:private_cidr_block) do
        vpc_cidr_block.gsub(/([[:digit:]]{1,3}\.?){2,2}\/[[:digit:]]{1,2}$/, '1.0/24')
      end
    end

    Contract None => String
    def ami_owner
      lookup(:ami_owner) { '099720109477' }
    end

    Contract None => String
    def ubuntu_release
      lookup(:ubuntu_release) { '14.04' }
    end

    Contract None => String
    def instance_type
      lookup(:instance_type) { 't2.micro' }
    end

    Contract None => String
    def ssh_dir
      lookup(:ssh_dir) { [workdir, '.ssh'].join('/') }
    end

    Contract None => String
    def ssh_username
      lookup(:ssh_username) { 'ubuntu' }
    end

    Contract None => String
    def hdp_dir
      @hdp_dir ||= File.expand_path(ENV.fetch('BOOTSTRAP_HDP_DIR') { dir })
    end

    Contract None => String
    def hdp_bootstrap_origin
      lookup :hdp_bootstrap_origin
    end

    alias hdp_origin hdp_bootstrap_origin

    Contract None => String
    def hdp_bootstrap_version
      lookup :hdp_bootstrap_version
    end

    alias hdp_version hdp_bootstrap_version

    Contract None => String
    def hdp_bootstrap_package_url
      lookup(:hdp_bootstrap_package_url) do
        "#{hdp_origin}/hcp-bootstrap_#{hdp_version.gsub('+', '%2B')}_amd64.deb"
      end
    end

    alias hdp_package_url hdp_bootstrap_package_url

    Contract None => String
    def bootstrap_properties_seed_url
      lookup :bootstrap_properties_seed_url
    end

    private

    StringToString = Func[Maybe[String] => Maybe[String]]

    Contract RespondTo[:to_s], Maybe[Or[String, StringToString]] => Maybe[String]
    def memoize(key, value = nil)
      key = key.to_s.tap { |k| k.prepend('@') unless k.start_with?('@') }
      return instance_variable_get(key) if instance_variable_defined?(key)

      instance_variable_set(key, block_given? ? yield(key) : value)
    end

    Contract RespondTo[:to_s], Maybe[Or[String, StringToString]] => String
    def lookup(key = __callee__, default = nil)
      memoize(key) do
        ENV.fetch("BOOTSTRAP_#{key.to_s.upcase}") do
          config.fetch(key.to_s) do
            block_given? ? yield(key) : default
          end
        end
      end
    end

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
