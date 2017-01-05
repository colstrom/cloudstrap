require 'faraday'
require 'multi_json'

module Cloudstrap
  class ComponentVersions
    def initialize(config)
      @config = config
      self
    end

    def hcp
      version_from https.get @config.hcp_metadata
    end

    def hce
      version_from https.get @config.hce_metadata
    end

    def hsm
      version_from https.get @config.hsm_metadata
    end

    private

    def https
      @https ||= Faraday.new "https://#{@config.artifact_origin}"
    end

    def version_from(response)
      return unless response.success?

      MultiJson.load(response.body).fetch('Version')
    end
  end
end
