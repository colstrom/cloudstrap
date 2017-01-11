require_relative 'hook'

module Cloudstrap
  module Hooks
    def hooks
      return [] unless Dir.exist? config.hooks_dir

      Dir
        .entries(config.hooks_dir)
        .reject { |entry| %w(. ..).include? entry }
        .map { |entry| Hook.new entry, host: jumpbox_ip, key: ssh_key.private_file }
    end

    def hook(name)
      hook = hooks.find { |h| h.name == name }
      return unless hook
      hook.call
    end

    def hooking(event)
      return unless block_given?
      hook "pre-#{event}"
      yield.tap { hook "post-#{event}" }
    end
  end
end
