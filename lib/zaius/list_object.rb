module Zaius
  class ListObject < ZaiusObject
    include Enumerable
    include Zaius::APIOperations::List
    include Zaius::APIOperations::Request
    # include Zaius::APIOperations::Create

    OBJECT_NAME = "list".freeze

    # This accessor allows a `ListObject` to inherit various filters that were
    # given to a predecessor. This allows for things like consistent limits,
    # expansions, and predicates as a user pages through resources.
    attr_accessor :filters

    # An empty list object. This is returned from +next+ when we know that
    # there isn't a next page in order to replicate the behavior of the API
    # when it attempts to return a page beyond the last.
    def self.empty_list(opts = {})
      ListObject.construct_from({ data: [] }, opts)
    end

    def initialize(*args)
      super
      self.filters = {}
    end

    def [](k)
      case k
      when String, Symbol
        super
      else
        raise ArgumentError, "You tried to access the #{k.inspect} index, but ListObject types only support String keys. (HINT: List calls return an object with a 'data' (which is the data array). You likely want to call #data[#{k.inspect}])"
      end
    end

    # Iterates through each resource in the page represented by the current
    # `ListObject`.
    #
    # Note that this method makes no effort to fetch a new page when it gets to
    # the end of the current page's resources. See also +auto_paging_each+.
    def each(&blk)
      data.each(&blk)
    end

    def retrieve(id, opts = {})
      id, retrieve_params = Util.normalize_id(id)
      resp, opts = request(:get, "#{resource_url}/#{CGI.escape(id)}", retrieve_params, opts)
      Util.convert_to_zaius_object(resp.data, opts)
    end

    def resource_url
      url ||
        raise(ArgumentError, "List object does not contain a 'url' field.")
    end
  end
end
