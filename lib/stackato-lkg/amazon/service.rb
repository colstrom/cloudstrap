require 'aws-sdk'
require 'contracts'
require_relative 'support/rate_limit_handler'
require_relative '../config'

module StackatoLKG
  module Amazon
    class Service
      include ::Contracts::Core
      include ::Contracts::Builtin
      include Support::RateLimitHandler

      Contract Maybe[Config] => Service
      def initialize(config = nil)
        @config = config
        self
      end

      Contract None => Aws::Client
      def client
        raise NotImplementedError
      end

      Contract None => Aws::Client
      def api
        @api ||= client.new region: config.region
      end

      Contract None => Config
      def config
        @config ||= Config.new
      end
    end
  end
end
