require 'arjdbc/mssql/types/numeric_types'
require 'arjdbc/mssql/types/string_types'
require 'arjdbc/mssql/types/binary_types'

# MSSQL type definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class Boolean < ActiveRecord::Type::Boolean
        end

        class UUID < ActiveRecord::Type::String
          ACCEPTABLE_UUID = %r{\A\{?([a-fA-F0-9]{4}-?){8}\}?\z}x

          def type
            :uuid
          end

          def type_cast(value)
            value.to_s[ACCEPTABLE_UUID, 0]
          end
        end

        class XML < ActiveRecord::Type::String
          def type
            :xml
          end

          def type_cast_for_database(value)
            return unless value
            Data.new(super)
          end

          class Data
            def initialize(value)
              @value = value
            end

            def to_s
              @value
            end
          end
        end

      end
    end



    # @private
    class BigIntegerType < ActiveRecord::Type::BigInteger
      def type; :bigint end
    end

    # @private
    SmallIntegerType = ActiveRecord::Type::Integer

    # @private
    class TinyIntegerType < ActiveRecord::Type::Integer
      def max_value; 256 end
      def min_value;   0 end
    end

    # @private
    class RealType < ActiveRecord::Type::Float
      def type; :real end
    end

    # @private
    class DecimalType < ActiveRecord::Type::Decimal

      private

      def cast_value(value)
        return 0 if value.equal? false
        return 1 if value.equal? true

        if @scale == 0 # act-like an integer
          return value.to_i rescue nil
        end

        case value
        when ::Float
          if precision
            BigDecimal(value, float_precision)
          else
            value.to_d
          end
        when ::Numeric, ::String
          BigDecimal(value, precision.to_i)
        else
          if value.respond_to?(:to_d)
            value.to_d
          else
            BigDecimal(value.to_s, precision.to_i)
          end
        end
      end

      def float_precision
        if precision.to_i > ::Float::DIG + 1
          ::Float::DIG + 1
        else
          precision.to_i
        end
      end

      #def max_value; ::Float::INFINITY end

    end

    # @private
    class MoneyType < DecimalType
      def type; :money end
      def initialize(options = {})
        super; @precision = 19; @scale = 4
      end
    end

    # @private
    class SmallMoneyType < MoneyType
      def type; :smallmoney end
      def initialize(options = {})
        super; @precision = 10; @scale = 4
      end
    end

    # @private
    class DateTimeType < ActiveRecord::Type::DateTime

      def type_cast_for_schema(value)
        value.acts_like?(:string) ? "'#{value}'" : "'#{value.to_s(:db)}'"
      end

      private

      def cast_value(value)
        value = value.respond_to?(:usec) ? value : super
        return unless value
        value.change usec: cast_usec(value)
      end

      def cast_usec(value)
        return 0 if !value.respond_to?(:usec) || value.usec.zero?
        seconds = value.usec.to_f / 1_000_000.0
        second_precision = 0.00333
        ss_seconds = ((seconds * (1 / second_precision)).round / (1 / second_precision)).round(3)
        (ss_seconds * 1_000_000).to_i
      end

    end

    # @private
    class SmallDateTimeType < DateTimeType
      def cast_usec(value); 0 end
      def cast_usec_for_database(value); '.000' end
    end

    # @private
    class TimeType < ActiveRecord::Type::Time

      def initialize(options = {})
        super; @precision = nil if @precision == 7
      end

      def type_cast_for_schema(value)
        value.acts_like?(:string) ? "'#{value}'" : super
      end

      private

      def cast_value(value)
        value = if value.respond_to?(:usec)
                  value.change(year: 2000, month: 1, day: 1)
                else
                  cast_value_like_super(value)
                end

        return if value.blank?
        value.change usec: cast_usec(value)
      end

      def cast_value_like_super(value)
        return value unless value.is_a?(::String)
        return if value.empty?

        dummy_value = "2000-01-01 #{value}"

        fast_string_to_time(dummy_value) || DateTime.parse(dummy_value).to_time # rescue nil
      end

      def cast_usec(value)
        (usec_to_seconds_frction(value) * 1_000_000).to_i
      end

      def usec_to_seconds_frction(value)
        (value.usec.to_f / 1_000_000.0).round(precision || 7)
      end

      #def quote_usec(value)
      #  usec_to_seconds_frction(value).to_s.split('.').last
      #end

    end

    # @private
    StringType = ActiveRecord::Type::String

    # @private
    class CharType < StringType
      def type; :char end
    end

    # @private
    class VarcharType < StringType
      def type; :varchar end
      def initialize(options = {})
        super; @limit = 8000 if @limit.to_i == 0
      end
    end

    # @private
    class TextType < StringType
      def type; :text_basic end
    end

    # @private
    class VarcharMaxType < TextType
      def type; :varchar_max end
      def limit; @limit ||= 2_147_483_647 end
    end

    # @private
    class UnicodeCharType < StringType
      def type; :nchar end
    end

    # @private
    class UnicodeVarcharType < StringType
      def type; :string end
      def initialize(options = {})
        super; @limit = 4000 if @limit.to_i == 0
      end
    end

    # @private
    class UnicodeVarcharMaxType < TextType
      def type; :text end # :nvarchar_max end
      def limit; @limit ||= 2_147_483_647 end
    end

    # @private
    class UnicodeTextType < TextType
      def type; :ntext end
      def limit; @limit ||= 2_147_483_647 end
    end

    # @private
    class BinaryType < ActiveRecord::Type::Binary
      def type; :binary_basic end
    end

    # @private
    class ImageType < BinaryType # ActiveRecord::Type::Binary
      def type; :binary end
      def limit; @limit ||= 2_147_483_647 end
    end

    # @private
    class VarbinaryType < BinaryType # ActiveRecord::Type::Binary
      def type; :varbinary end
      def initialize(options = {})
        super; @limit = 8000 if @limit.to_i == 0
      end
    end

    # @private
    class VarbinaryMaxType < BinaryType # ActiveRecord::Type::Binary
      def type; :varbinary_max end
      def limit; @limit ||= 2_147_483_647 end
    end

    # @private
    class UUIDType < ActiveRecord::Type::String
      def type; :uuid end

      # FIXME: type_cast_from_database is not defined anymore
      # alias_method :type_cast_for_database, :type_cast_from_database

      ACCEPTABLE_UUID = %r{\A\{?([a-fA-F0-9]{4}-?){8}\}?\z}x
      def type_cast(value); value.to_s[ACCEPTABLE_UUID, 0] end
    end

    # @private
    class XmlType < ActiveRecord::Type::String
      def type; :xml end

      def type_cast_for_database(value)
        return unless value
        Data.new(super)
      end

      class Data
        def initialize(value)
          @value = value
        end
        def to_s; @value end
      end
    end

  end
end
