require 'contracts'
require 'faraday'
require_relative 'config'

module Cloudstrap
  class SeedProperties
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract None => String
    def source
      config.bootstrap_properties_seed_url
    end

    Contract None => ::Faraday::Response
    def connection
      @connection ||= ::Faraday.get source
    end

    Contract None => Maybe[String]
    def contents
      @contents ||= connection.body if connection.success?
    end

    Contract None => Config
    def config
      @config ||= Config.new
    end
  end
end
