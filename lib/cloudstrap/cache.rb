require 'contracts'
require 'moneta'

require_relative 'config'

module Cloudstrap
  class Cache
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract RespondTo[:to_s], Maybe[RespondTo[:call]] => Maybe[Any]
    def get(key)
      persistence.fetch(key.to_s) do
        # TODO: Remove symbol fallback for 1.0
        persistence.fetch(key.to_s.to_sym) do
          yield if block_given?
        end
      end
    end

    Contract RespondTo[:to_s], Any => Any
    def set(key, value)
      persistence.store key.to_s, value
    end

    Contract RespondTo[:to_s] => Maybe[Any]
    def delete(key)
      #TODO: Remove symbol fallback for 1.0
      persistence.delete(key.to_s) || persistence.delete(key.to_s.to_sym)
    end

    Contract RespondTo[:to_s], Maybe[RespondTo[:call]] => Maybe[Any]
    def call(key)
      get(key) { set key, yield if block_given? }
    end

    Contract None => ::Moneta::Proxy
    def persistence
      @persistence ||= ::Moneta.new :File, dir: config.cache_path
    end

    Contract None => Config
    def config
      @config ||= Config.new
    end
  end
end
