module Zaius
  class ZaiusClient
    attr_accessor :conn

    # Initializes a new ZaiusClient. Expects a Faraday connection object, and
    # uses a default connection unless one is passed.
    def initialize(conn = nil)
      self.conn = conn || self.class.default_conn
    end

    def self.default_client
      Thread.current[:zaius_client_default_client] ||= ZaiusClient.new(default_conn)
    end

    def self.active_client
      Thread.current[:zaius_client] || default_client
    end

    # A default Faraday connection to be used when one isn't configured. This
    # object should never be mutated, and instead instantiating your own
    # connection and wrapping it in a ZaiusClient object should be preferred.
    def self.default_conn
      # We're going to keep connections around so that we can take advantage
      # of connection re-use, so make sure that we have a separate connection
      # object per thread.
      Thread.current[:zaius_client_default_conn] ||= begin
        conn = Faraday.new do |c|
          c.use Faraday::Request::Multipart
          c.use Faraday::Request::UrlEncoded
          c.use Faraday::Response::RaiseError
          c.adapter Faraday.default_adapter
        end

        conn
      end
    end

    def request_headers(api_key, method)
      user_agent = "Zaius/v1 RubyBindings/#{Zaius::VERSION}"

      headers = {
        "User-Agent" => user_agent,
        "x-api-key" => api_key,
        "Content-Type" => "application/json",
      }

      headers
    end

    def execute_request(method, path,
                        api_base: nil, api_key: nil, headers: {}, params: {})

      api_base ||= Zaius.api_base
      api_key ||= Zaius.api_key

      check_api_key!(api_key)

      url = api_url(path, api_base)

      body = nil
      query_params = nil

      case method.to_s.downcase.to_sym
      when :get, :head, :delete
        query_params = params
      else
        body = params.to_json
      end

      # This works around an edge case where we end up with both query
      # parameters in `query_params` and query parameters that are appended
      # onto the end of the given path. In this case, Faraday will silently
      # discard the URL's parameters which may break a request.
      #
      # Here we decode any parameters that were added onto the end of a path
      # and add them to `query_params` so that all parameters end up in one
      # place and all of them are correctly included in the final request.
      # u = URI.parse(path)
      # unless u.query.nil?
      #   query_params ||= {}
      #   query_params = Hash[URI.decode_www_form(u.query)].merge(query_params)

      #   # Reset the path minus any query parameters that were specified.
      #   path = u.path
      # end

      headers = request_headers(api_key, method)
                .update(headers)

      # stores information on the request we're about to make so that we don't
      # have to pass as many parameters around for logging.
      context = RequestLogContext.new
      context.api_key         = api_key
      context.body            = body
      context.method          = method
      context.path            = path
      context.query_params    = query_params ? Util.encode_parameters(query_params) : nil

      http_resp = execute_request_with_rescues(api_base, context) do
        conn.run_request(method, url, body, headers) do |req|
          req.params = query_params unless query_params.nil?
        end
      end

      begin
        resp = ZaiusResponse.from_faraday_response(http_resp)
      rescue JSON::ParserError
        raise general_api_error(http_resp.status, http_resp.body)
      end

      # Allows ZaiusClient#request to return a response object to a caller.
      @last_response = resp
      [resp, api_key]
    end

    def execute_request_with_rescues(api_base, context)
      num_retries = 0
      begin
        request_start = Time.now
        log_request(context, num_retries)
        resp = yield
        context = context.dup_from_response(resp)
        log_response(context, request_start, resp.status, resp.body)

      # We rescue all exceptions from a request so that we have an easy spot to
      # implement our retry logic across the board. We'll re-raise if it's a type
      # of exception that we didn't expect to handle.
      rescue StandardError => e
        # If we modify context we copy it into a new variable so as not to
        # taint the original on a retry.
        error_context = context

        if e.respond_to?(:response) && e.response
          error_context = context.dup_from_response(e.response)
          log_response(error_context, request_start,
                       e.response[:status], e.response[:body])
        else
          log_response_error(error_context, request_start, e)
        end

        case e
        when Faraday::ClientError
          if e.response
            handle_error_response(e.response, error_context)
          else
            handle_network_error(e, error_context, num_retries, api_base)
          end

        # Only handle errors when we know we can do so, and re-raise otherwise.
        # This should be pretty infrequent.
        else
          raise
        end
      end

      resp
    end

    def handle_error_response(http_resp, context)
      begin
        resp = ZaiusResponse.from_faraday_hash(http_resp)
        error_data = resp.data[:title]

        raise ZaiusError, "Indeterminate error" if resp.data[:title].nil?
      rescue JSON::ParserError, ZaiusError
        raise general_api_error(http_resp[:status], http_resp[:body])
      end

      error = specific_api_error(resp, error_data, context)

      error.response = resp
      raise(error)
    end

    def general_api_error(status, body)
      ZaiusError.new("Invalid response object from API: #{body.inspect} " \
                   "(HTTP response code was #{status})",
                   http_status: status, http_body: body)
    end

    def specific_api_error(response, error_data, context)
      response_data = response.data

      APIError.new(title: response_data[:title], http_status: response.http_status, detail: response_data[:detail])
    end

    def log_response(context, request_start, status, body)
      Util.log_info("Response from Zaius",
                    account: context.account,
                    api_version: context.api_version,
                    elapsed: Time.now - request_start,
                    method: context.method,
                    path: context.path,
                    request_id: context.request_id,
                    url: context.url,
                    status: status)
      Util.log_debug("Response details",
                     body: body,
                      request_id: context.request_id)
    end

    def log_request(context, num_retries)
      Util.log_info("Request to Zaius",
                    account: context.account,
                    api_version: context.api_version,
                    method: context.method,
                    num_retries: num_retries,
                    path: context.path)
      Util.log_debug("Request details",
                     body: context.body,
                     query_params: context.query_params)
    end
    private :log_request

    def log_response_error(context, request_start, e)
      Util.log_error("Request error",
                     elapsed: Time.now - request_start,
                     error_message: e.message,
                      method: context.method,
                     path: context.path)
    end

    def api_url(url = "", api_base = nil)
      (api_base || Zaius.api_base) + url
    end

    def check_api_key!(api_key)
      unless api_key
        raise AuthenticationError, "No API key provided. " \
          'Set your API key using "Zaius.api_key = <API-KEY>". '
      end

      return unless api_key =~ /\s/

      raise AuthenticationError, "Your API key is invalid, as it contains whitespace."
    end
  end

  # RequestLogContext stores information about a request that's begin made so
  # that we can log certain information. It's useful because it means that we
  # don't have to pass around as many parameters.
  class RequestLogContext
    attr_accessor :body
    attr_accessor :account
    attr_accessor :api_key
    attr_accessor :api_version
    attr_accessor :method
    attr_accessor :path
    attr_accessor :query_params
    attr_accessor :request_id
    attr_accessor :url

    # The idea with this method is that we might want to update some of
    # context information because a response that we've received from the API
    # contains information that's more authoritative than what we started
    # with for a request.
    def dup_from_response(resp)
      return self if resp.nil?

      # Faraday's API is a little unusual. Normally it'll produce a response
      # object with a `headers` method, but on error what it puts into
      # `e.response` is an untyped `Hash`.
      headers = if resp.is_a?(Faraday::Response)
                  resp.headers
                else
                  resp[:headers]
                end

      context = dup
      context
    end
  end
end
