require 'aws-sdk'
require 'contracts'
require_relative 'service'

module StackatoLKG
  module Amazon
    class IAM < Service
      Contract None => ::Aws::IAM::Types::User
      def user
        @user ||= call_api(:get_user).user
      end

      private

      def client
        Aws::IAM::Client
      end
    end
  end
end
