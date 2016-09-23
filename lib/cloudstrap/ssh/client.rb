require 'contracts'
require 'sshkit'

module StackatoLKG
  module SSH
    class Client
      include ::Contracts::Core
      include ::Contracts::Builtin

      Contract String => Client
      def initialize(private_key)  # TODO: Eliminate side-effects
        ::SSHKit::Backend::Netssh.configure do |ssh|
          ssh.ssh_options = {
            config: false,
            auth_methods: ['publickey'],
            keys: private_key,
            keys_only: true
          }
        end

        self
      end

      Contract String, Proc => Any
      def to(host, &block)
        ::SSHKit::Coordinator.new("#{config.ssh_username}@#{host}").each(&block)
      end

      private

      Contract None => ::StackatoLKG::Config
      def config
        @config ||= ::StackatoLKG::Config.new
      end
    end
  end
end
