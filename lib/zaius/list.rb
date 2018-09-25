module Zaius
  class List < APIResource
    extend Zaius::APIOperations::List

    OBJECT_NAME = "list".freeze
  end
end
