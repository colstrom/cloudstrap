require 'contracts'
require 'sshkit'

module Cloudstrap
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

      Contract String, Maybe[Proc] => Any
      def to(host, &block)
        ::SSHKit::Coordinator.new("#{config.ssh_username}@#{host}")
      end

      private

      Contract None => Config
      def config
        @config ||= Config.new
      end
    end
  end
end
