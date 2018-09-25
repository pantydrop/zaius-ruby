module Zaius
  class ZaiusError < StandardError

    attr_reader :code
    attr_reader :http_body
    attr_reader :http_headers
    attr_reader :http_status
    attr_reader :json_body # equivalent to #data

    attr_accessor :response

    def initialize(message = nil, http_status: nil, http_body: nil, json_body: nil,
                   http_headers: nil, code: nil)
      @message = message
      @http_status = http_status
      @http_body = http_body
      @http_headers = http_headers || {}
      @json_body = json_body
      @code = code
    end

    def to_s
      status_string = @http_status.nil? ? "" : "(Status #{@http_status}) "
      "#{status_string}#{@message}"
    end
  end

  class APIError < ZaiusError
    def initialize(title:, http_status: nil, detail: {})
      @message = title
      @http_status = http_status

      @json_body = detail

      def to_s
        status_string = @http_status.nil? ? "" : "(Status #{@http_status}) "
        "#{status_string}#{@message}: #{json_body}"
      end
    end
  end

  class AuthenticationError < StandardError
  end
end