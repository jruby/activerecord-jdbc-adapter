# frozen_string_literal: true

require "active_model/attribute"

module ActiveRecord
  # NOTE: improved implementation for hash methods that is used to
  # compare objects. AR and arel commonly use `[a, b] - [b]` operations and
  # JRuby internally uses the hash method to implement that operation,
  # on the other hand, CRuby does not use the hash method
  # for small arrays (length <= 16).
  class Relation
    # monkey patch
    module RelationQueryAttributeMonkeyPatch
      def hash
        # [self.class, name, value_for_database, type].hash
        [self.class, name, value_before_type_cast, type].hash
      end
    end

    class QueryAttribute
      prepend RelationQueryAttributeMonkeyPatch
    end
  end
end
