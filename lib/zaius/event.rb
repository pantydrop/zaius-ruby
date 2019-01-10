module Zaius
  class Event < APIResource
    OBJECT_NAME = "Event".freeze

    def self.subscribe(list_id:, email:, params: {}, opts: {})
      data = {
        list_id: list_id
      }.merge(params)

      body = {
        type: "list",
        action: "subscribe",
        identifiers: { 
          email: email
        },
        data: data
      }

      resp, opts = request(:post, resource_url, body, opts)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def resource_url
      "/events"
    end
  end
end
