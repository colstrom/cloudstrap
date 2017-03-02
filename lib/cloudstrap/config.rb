require 'contracts'
require 'pastel'
require 'yaml'

require_relative 'component_versions'

module Cloudstrap
  class Config
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract None => String
    def region
      lookup(:region) do
        Aws::EC2::Client.new.config.region || 'us-west-2'
      end
    end

    Contract None => String
    def cache_path
      lookup(:cache_path) { [workdir, '.cache'].join('/') }
    end

    Contract None => String
    def network_bits
      lookup(:network_bits) { '16' }
    end

    Contract None => String
    def subnet_bits
      lookup(:subnet_bits) { '24' }
    end

    Contract None => String
    def vpc_cidr_block
      lookup(:vpc_cidr_block) { '10.0.0.0/16' }
    end

    Contract None => String
    def public_cidr_block
      lookup(:public_cidr_block) do
        vpc_cidr_block.gsub(/([[:digit:]]{1,3}\.?){2,2}\/[[:digit:]]{1,2}$/, "0.0/#{subnet_bits}")
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
    def hce_metadata
      lookup(:hce_metadata) do
        "#{hce_prefix}/dist/v2/linux-amd64.json"
      end.squeeze('/')
    end

    Contract None => String
    def hce_version
      lookup(:hce_version) { latest.hce }
    end

    Contract None => String
    def hsm_prefix
      lookup(:hsm_prefix) do
        "#{artifact_prefix}/hsm"
      end.squeeze('/')
    end

    Contract None => String
    def hsm_metadata
      lookup(:hsm_metadata) do
        "#{hsm_prefix}/cli/update/linux-amd64.json"
      end.squeeze('/')
    end

    Contract None => String
    def hsm_version
      lookup(:hsm_version) { latest.hsm }
    end

    Contract None => String
    def hcp_prefix
      lookup(:hcp_prefix) do
        "#{artifact_prefix}/hcp"
      end.squeeze('/')
    end

    Contract None => String
    def hcp_channel
      lookup(:hcp_channel) do
        case channel
        when 'dev'
          'hcp_0.9_development'
        when 'release'
          'hcp_1.0_stable'
        end
      end
    end

    Contract None => String
    def hcp_metadata
      lookup(:hcp_metadata) do
        "#{hcp_prefix}/cli/update/#{hcp_channel}/linux-amd64.json"
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
      lookup(:hcp_bootstrap_version) { latest.hcp }
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

    Contract None => String
    def hooks_dir
      lookup(:hooks_dir) { [workdir, 'hooks'].join('/') }
    end

    Contract None => String
    def remote_hooks_dir
      lookup(:remote_hooks_dir) { '.cloudstrap/hooks' }
    end

    Contract None => Pos
    def maximum_availability_zones
      lookup(:maximum_availability_zones) { '3' }.to_i
    end

    Contract None => Pos
    def minimum_availability_zones
      lookup(:minimum_availability_zones) { '1' }.to_i
    end

    Contract None => String
    def environment_namespace
      lookup(:environment_namespace) { 'CLOUDSTRAP' }.upcase
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
      @file ||= ENV.fetch('BOOTSTRAP_CONFIG_FILE') do
        %w(config.yaml config.yml).find { |f| File.exist? "#{dir}/#{f}" }
      end
    end

    Contract None => String
    def path
      @path ||= File.expand_path [dir, file].join('/')
    end

    Contract None => ComponentVersions
    def latest
      @latest ||= ComponentVersions.new self
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
