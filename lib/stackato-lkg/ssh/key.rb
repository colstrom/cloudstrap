require 'contracts'
require 'sshkey'
require_relative '../config'

module StackatoLKG
  module SSH
    class Key
      include ::Contracts::Core
      include ::Contracts::Builtin

      Contract String, KeywordArgs[ephemeral: Optional[Bool]] => Key
      def initialize(name, **with_options)
        @name = name
        if loadable? then load else generate(with_options) end
        self
      end

      Contract None => String
      def to_s
        @key.ssh_public_key
      end

      Contract None => ::SSHKey
      def load
        @key ||= load!
      end

      Contract None => ::SSHKey
      def load!
        @key = ::SSHKey.new(File.read private_file).tap do |key|
          raise ::EncodingError unless valid?(key.ssh_public_key)
        end
      end

      Contract ::SSHKey => ::SSHKey
      def save(key)
        FileUtils.mkdir_p dir
        File.write public_file, key.ssh_public_key
        File.write private_file, key.private_key
        File.chmod 0400, private_file
        load!
      end

      Contract KeywordArgs[ephemeral: Optional[Bool]] => ::SSHKey
      def generate(ephemeral: false)
        ::SSHKey.generate(type: 'RSA', comment: @name).tap do |key|
          save key unless ephemeral
        end
      end

      Contract None => Bool
      def loadable?
        File.readable? private_file
      end

      private

      Contract String => Bool
      def valid?(public_key)
        ::SSHKey.valid_ssh_public_key? public_key
      end

      Contract None => String
      def public_file
        @public_file ||= [private_file, 'pub'].join('.')
      end

      Contract None => String
      def private_file
        @private_file ||= [dir, File.basename(@name)].join('/')
      end

      Contract None => String
      def dir
        @dir ||= [
          ::StackatoLKG::Config.new.ssh_dir,
          File.dirname(@name)
        ].join('/')
      end
    end
  end
end
