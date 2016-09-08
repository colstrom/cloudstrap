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

    Contract None => ::StackatoLKG::Config
    def config
      @config ||= ::StackatoLKG::Config.new
    end
  end
end
