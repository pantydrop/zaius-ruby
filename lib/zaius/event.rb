module Zaius
  class Event < APIResource
    OBJECT_NAME = "Event".freeze

    def self.subscribe(list_id:, email:, params: {}, opts: {})
      list_ids = Array(list_id)

      body = list_ids.map do |list|
        data = {
          list_id: list
        }.merge(params)
        
        {
          type: "list",
          action: "subscribe",
          identifiers: { 
            email: email
          },
          data: data
        }
      end

      resp, opts = request(:post, resource_url, body, opts)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def resource_url
      "/events"
    end
  end
end
