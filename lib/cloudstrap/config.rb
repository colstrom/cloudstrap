require 'contracts'
require 'pastel'
require 'yaml'

module Cloudstrap
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
    def node_instance_type
      lookup(:node_instance_type) { 'm4.xlarge' }
    end

    Contract None => String
    def master_instance_type
      lookup(:master_instance_type) { 't2.medium' }
    end

    Contract None => String
    def gluster_instance_type
      lookup(:gluster_instance_type) { 't2.medium' }
    end

    Contract None => Or[Num, String]
    def node_count
      lookup(:node_count) { '3' }.to_s
    end

    Contract None => Or[Num, String]
    def master_count
      lookup(:master_count) { '3' }.to_s
    end

    Contract None => Or[Num, String]
    def gluster_count
      lookup(:gluster_count) { '2' }.to_s
    end

    Contract None => String
    def ssh_dir
      lookup(:ssh_dir) { [workdir, '.ssh'].join('/') }
    end

    Contract None => String
    def ssh_username
      lookup(:ssh_username) { 'ubuntu' }
    end

    Contract None => Enum['dev', 'release']
    def channel
      lookup(:channel) { 'release' }
    end

    Contract None => String
    def artifact_origin
      lookup(:artifact_origin) do
        case channel
        when 'release'
          'release.stackato.com'
        when 'dev'
          'dev.stackato.com'
        end
      end
    end

    Contract None => String
    def artifact_prefix
      lookup(:artifact_prefix) { '/downloads' }
    end

    Contract None => String
    def hce_prefix
      lookup(:hce_prefix) do
        "#{artifact_prefix}/hce"
      end.squeeze('/')
    end

    Contract None => String
    def hsm_prefix
      lookup(:hsm_prefix) do
        "#{artifact_prefix}/hsm"
      end.squeeze('/')
    end

    Contract None => String
    def hcp_prefix
      lookup(:hcp_prefix) do
        "#{artifact_prefix}/hcp"
      end.squeeze('/')
    end

    Contract None => String
    def hcp_dir
      @hcp_dir ||= File.expand_path(ENV.fetch('BOOTSTRAP_HCP_DIR') { dir })
    end

    Contract None => String
    def hcp_bootstrap_origin
      lookup(:hcp_bootstrap_origin) { 'https://release.stackato.com/downloads/hcp/bootstrap' }
    end

    alias hcp_origin hcp_bootstrap_origin

    Contract None => String
    def hcp_bootstrap_version
      lookup(:hcp_bootstrap_version) { '1.0.21-0-g77ce3d1' }
    end

    alias hcp_version hcp_bootstrap_version

    Contract None => String
    def hcp_bootstrap_package_url
      lookup(:hcp_bootstrap_package_url) do
        version = hcp_bootstrap_version.gsub('+', '%2B')
        'https://' + [
          artifact_origin,
          hcp_prefix,
          'bootstrap',
          "hcp-bootstrap_#{version}_amd64.deb"
        ].join('/').squeeze('/')
      end
    end

    alias hcp_package_url hcp_bootstrap_package_url

    Contract None => String
    def properties_seed_url
      lookup(:properties_seed_url) { '' }
    end

    Contract None => String
    def bootstrap_properties_seed_url
      properties_seed_url
    end

    Contract None => String
    def domain_name
      required :domain_name
    end

    private

    Contract None => ::Pastel::Delegator
    def pastel
      @pastel ||= Pastel.new
    end

    Contract RespondTo[:to_s] => nil
    def abort_on_missing(key)
      STDERR.puts pastel.red <<EOS

#{pastel.bold key} is required, but is not configured.

You can resolve this by adding it to #{pastel.bold file}, or by
setting #{pastel.bold('BOOTSTRAP_' + key.to_s.upcase)} in the environment.
EOS
      abort
    end

    Contract RespondTo[:to_s] => String
    def required(key)
      lookup(key, '').tap { |value| abort_on_missing key if value.empty? }
    end

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
                      YAML.load_file(path).map { |k, v| [k, v.to_s] }.to_h
                    else
                      {}
                    end
    end
  end
end
