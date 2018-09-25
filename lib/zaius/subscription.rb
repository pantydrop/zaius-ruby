module Zaius
  class Subscription < APIResource
    OBJECT_NAME = "subscription".freeze

    def self.resource_url
      "/lists/subscriptions"
    end

    def self.list(params = {}, opts = {})
      resp, opts = request(:get, resource_url, params, opts)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def self.update_opt_in(params = {}, opts = {})
      resp, opts = request(:post, resource_url, params, opts)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def self.update(email: nil, list_id: nil, subscribed: false)
      params = { email: email, list_id: list_id, subscribed: subscribed }
      resp, opts = request(:post, resource_url, params)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def self.update_list(opted_in: true, email:, lists: [])
      body = lists.map do |list|
        [
          { opted_in: opted_in, email: email },
          { list_id: list[:id], email: email, subscribed: list[:subscribed] }
        ]
      end.flatten
      resp, opts = request(:post, resource_url, body)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def self.opt_out(params = {}, opts = {})
      params[:opted_in] = false
      resp, opts = request(:post, resource_url, params, opts)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def self.opt_in(params = {}, opts = {})
      params[:opted_in] = true

      resp, opts = request(:post, resource_url, params, opts)

      ZaiusObject.construct_from(resp.data, opts)
    end

    def resource_url
      self.class.resource_url
    end
  end
end
