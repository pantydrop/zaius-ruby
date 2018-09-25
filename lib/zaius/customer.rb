module Zaius
  class Customer < APIResource
    OBJECT_NAME = "customer".freeze

    def resource_url
      "/profiles"
    end
  end
end
