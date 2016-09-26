require 'aws-sdk'
require 'contracts'
require 'retries'

module Cloudstrap
  module Amazon
    module Support
      module RateLimitHandler
        include ::Contracts::Core
        include ::Contracts::Builtin

        Contract None => Proc
        def request_limit_exceeded_handler
          Proc.new do |exception, attempt, seconds|
            STDERR.puts "Encountered a #{exception.class}. DON'T PANIC. Waiting and trying again works (usually). Let's do that! (this was attempt #{attempt} after #{seconds} seconds)"
          end
        end

        Contract Symbol, Args[Any] => Any
        def call_api(method, *args)
          with_retries(
            rescue: Aws::EC2::Errors::RequestLimitExceeded,
            handler: request_limit_exceeded_handler,
            base_sleep_seconds: 1.0,
            max_sleep_seconds: 8.0
          ) do
            api.method(method).call(*args)
          end
        end
      end
    end
  end
end
