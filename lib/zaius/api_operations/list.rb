# frozen_string_literal: true

module Zaius
  module APIOperations
    module List
      def list(filters = {}, opts = {})
        resp, opts = request(:get, resource_url, filters, opts)
        obj = ListObject.construct_from(resp.data, opts)

        obj
      end
    end
  end
end
