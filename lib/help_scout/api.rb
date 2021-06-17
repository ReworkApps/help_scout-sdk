# frozen_string_literal: true

module HelpScout
  class API
    class BadRequest < StandardError; end
    class NotAuthorized < StandardError; end
    class NotFound < StandardError; end
    class InternalError < StandardError; end
    class ThrottleLimitReached < StandardError
      attr_reader :time_to_reset

      def initialize(message, time_to_reset)
        super(message)
        @retry_after = retry_after
      end
    end

    BASE_URL = 'https://api.helpscout.net/v2/'

    attr_accessor :access_token

    def get(path, params = {})
      send_request(:get, path, params)
    end

    def patch(path, params)
      send_request(:patch, path, params)
    end

    def post(path, params)
      send_request(:post, path, params)
    end

    def put(path, params)
      send_request(:put, path, params)
    end

    private

    def handle_response(result) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if (200...300).include? result.status
        HelpScout::Response.new(result)
      else
        case result.status
        when 400 then raise BadRequest.new(result.body&.dig('validationErrors'))
        when 401 then raise NotAuthorized.new(result.body&.dig('error_description'))
        when 404 then raise NotFound.new('Resource Not Found')
        when 429 then raise ThrottleLimitReached.new(result.body&.dig('error'), result.headers['X-RateLimit-Retry-After'].to_i)
        else raise InternalError.new(result.body)
        end
      end
    end

    def new_connection
      HelpScout::API::Client.new.connection
    end

    def send_request(action, path, params)
      response = new_connection.send(action, path, params.compact)

      if response.status == 401
        access_token&.invalidate!
        response = new_connection.send(action, path, params.compact)
      end

      handle_response(response)
    end
  end
end
