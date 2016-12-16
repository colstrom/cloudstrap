require 'contracts'
require 'java-properties'

require_relative '../config'
require_relative '../seed_properties'

module Cloudstrap
  module HCP
    class BootstrapProperties
      include ::Contracts::Core
      include ::Contracts::Builtin

      Contract None => Hash
      def properties
        @properties ||= load!
      end

      Contract RespondTo[:to_sym], String => BootstrapProperties
      def update!(property, value)
        update(property, value).tap do
          save!
        end
      end

      Contract RespondTo[:to_sym], String => BootstrapProperties
      def update(property, value)
        raise KeyError unless properties.has_key? property.to_sym

        properties.store property.to_sym, value

        self
      end

      Contract RespondTo[:to_sym], String => BootstrapProperties
      def define(property, value)
        properties.store property.to_sym, value
        self
      end

      Contract None => Bool
      def save!
        JavaProperties.write(properties, file) ? true : false
      end

      Contract None => String
      def file
        @file ||= [config.hcp_dir, 'bootstrap.properties'].join('/')
      end

      private

      Contract None => SeedProperties
      def seed
        @seed ||= SeedProperties.new
      end

      Contract None => Bool
      def exist?
        File.exist?(file)
      end

      Contract None => Hash
      def load
        if exist?
          JavaProperties.load file
        else
          JavaProperties.parse ''
        end
      end

      Contract None => Hash
      def load!
        @properties = load
      end

      Contract None => Config
      def config
        @config ||= Config.new
      end
    end
  end
end
