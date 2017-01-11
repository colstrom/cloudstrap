require_relative 'cache'
require_relative 'config'

module Cloudstrap
  class Hook
    def initialize(name, **options)
      @name = name
      @options = options
      self
    end

    attr_reader :name

    alias to_s name
    alias to_str to_s

    def local
      "#{config.hooks_dir}/#{name}"
    end

    def remote
      "#{config.remote_hooks_dir}/#{name}"
    end

    def exists?
      File.exist? local
    end

    def enabled?
      File.executable? local
    end

    def disabled?
      !enabled?
    end

    def upload!
      return false unless exists?

      [local, remote].tap do |local_file, remote_file|
        ssh.to(host) {
          execute :mkdir, '-p', File.dirname(remote_file)
          upload! local_file, remote_file }
      end
    end

    def execute!
      return true unless enabled?

      remote.tap { |hook| ssh.to(host) { execute hook } }
    end

    def call
      upload! && execute!
    end

    private

    def ssh
      @ssh ||= SSH::Client.new key
    end

    def key
      @options.fetch(:key)
    end

    def host
      @options.fetch(:host)
    end

    def cache
      @cache ||= Cache.new
    end

    def config
      @config ||= Config.new
    end
  end
end
