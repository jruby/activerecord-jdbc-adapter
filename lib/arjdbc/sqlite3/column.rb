# frozen_string_literal: true

module ActiveRecord::ConnectionAdapters
  class SQLite3Column < JdbcColumn

    attr_reader :rowid

    def initialize(*, auto_increment: nil, rowid: false, generated_type: nil, **)
      super

      @auto_increment = auto_increment
      @default = nil if default =~ /NULL/
      @rowid = rowid
      @generated_type = generated_type
    end

    def self.string_to_binary(value)
      value
    end

    def self.binary_to_string(value)
      if value.respond_to?(:encoding) && value.encoding != Encoding::ASCII_8BIT
        value = value.force_encoding(Encoding::ASCII_8BIT)
      end
      value
    end

    # @override {ActiveRecord::ConnectionAdapters::JdbcColumn#default_value}
    def default_value(value)
      # JDBC returns column default strings with actual single quotes :
      return $1 if value =~ /^'(.*)'$/

      value
    end

    def auto_increment?
      @auto_increment
    end

    def auto_incremented_by_db?
      auto_increment? || rowid
    end

    def virtual?
      !@generated_type.nil?
    end

    def virtual_stored?
      virtual? && @generated_type == :stored
    end

    def has_default?
      super && !virtual?
    end

    def init_with(coder)
      @auto_increment = coder["auto_increment"]
      super
    end

    def encode_with(coder)
      coder["auto_increment"] = @auto_increment
      super
    end

    def ==(other)
      other.is_a?(Column) &&
        super &&
        auto_increment? == other.auto_increment?
    end
    alias :eql? :==

    def hash
      Column.hash ^
        super.hash ^
        auto_increment?.hash ^
        rowid.hash
    end

    # @override {ActiveRecord::ConnectionAdapters::Column#type_cast}
    def type_cast(value)
      return nil if value.nil?
      case type
        when :string then value
        when :primary_key
          value.respond_to?(:to_i) ? value.to_i : ( value ? 1 : 0 )
        when :float    then value.to_f
        when :decimal  then self.class.value_to_decimal(value)
        when :boolean  then self.class.value_to_boolean(value)
        else super
      end
    end

    private

    # @override {ActiveRecord::ConnectionAdapters::Column#extract_limit}
    def extract_limit(sql_type)
      return nil if sql_type =~ /^(real)\(\d+/i
      super
    end

    def extract_precision(sql_type)
      case sql_type
        when /^(real)\((\d+)(,\d+)?\)/i then $2.to_i
        else super
      end
    end

    def extract_scale(sql_type)
      case sql_type
        when /^(real)\((\d+)\)/i then 0
        when /^(real)\((\d+)(,(\d+))\)/i then $4.to_i
        else super
      end
    end
  end
end
