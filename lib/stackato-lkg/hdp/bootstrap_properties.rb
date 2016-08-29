require 'contracts'
require 'java-properties'

require_relative '../config'

module StackatoLKG
  module HDP
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

      Contract None => Bool
      def save!
        JavaProperties.write(properties, file) ? true : false
      end

      private

      Contract None => Hash
      def load
        JavaProperties.load file
      end

      Contract None => Hash
      def load!
        @properties = load
      end

      Contract None => String
      def file
        @file ||= [config.hdp_dir, 'bootstrap.properties'].join('/')
      end

      Contract None => ::StackatoLKG::Config
      def config
        @config ||= ::StackatoLKG::Config.new
      end
    end
  end
end
