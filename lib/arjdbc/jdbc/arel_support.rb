module ActiveRecord::ConnectionAdapters
  module Jdbc
    # AREL support for the JDBC adapter.
    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter
    module ArelSupport

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        def arel_visitor_name(spec)
          if spec
            if spec.respond_to?(:arel_visitor_name)
              spec.arel_visitor_name # for AREL built-in visitors
            else
              spec.name.split('::').last.downcase # ArJdbc::PostgreSQL -> postgresql
            end
          else # AR::ConnnectionAdapters::MySQLAdapter => mysql
            name.split('::').last.sub('Adapter', '').downcase
          end
        end

        # NOTE: it's important to track our own since we might want to override
        # what AREL setup for us e.g. we do not want `::Arel::Visitors::MSSQL`

        # @private
        RESOLVED_VISITORS = {} # lazy filled mirror of ::Arel::Visitors::VISITORS

        # @todo document
        def resolve_visitor_type(config)
          raise "missing :adapter in #{config.inspect}" unless adapter = config[:adapter]

          unless visitor_type = RESOLVED_VISITORS[ adapter ]
            if adapter_spec = config[:adapter_spec]
              if adapter_spec.respond_to?(:arel_visitor_type)
                visitor_type = adapter_spec.arel_visitor_type(config)
              elsif adapter_spec.respond_to?(:arel2_visitors) # backwards compat
                visitor_type = adapter_spec.arel2_visitors(config).values.first
              else # auto-convention ArJdbc::MySQL -> Arel::Visitors::MySQL
                const_name = adapter_spec.name.split('::').last
                visitor_type = ::Arel::Visitors.const_get(const_name) rescue nil
              end
            elsif respond_to?(:arel_visitor_type)
              visitor_type = arel_visitor_type(config) # adapter_class' override
            end

            visitor_type ||= ::Arel::Visitors::VISITORS[ arel_visitor_name(adapter_spec) ]
            visitor_type ||= ::Arel::Visitors::ToSql # default (if nothing resolved)

            RESOLVED_VISITORS.to_java.synchronized do
              RESOLVED_VISITORS[ adapter ] = ::Arel::Visitors::VISITORS[ adapter ] = visitor_type
            end
          end

          visitor_type
        end

        # @note called from `ActiveRecord::ConnectionAdapters::ConnectionPool.checkout` (up till AR-3.2)
        # @override
        def visitor_for(pool)
          visitor = resolve_visitor_type(config = pool.spec.config)
          ( prepared_statements?(config) ? visitor : bind_substitution(visitor) ).new(pool)
        end

        # @private
        @@bind_substitutions = nil

        # Generates a class for the given visitor type, this new {Class} instance
        # is a sub-class of `Arel::Visitors::BindVisitor`.
        # @return [Class] class for given visitor type
        def bind_substitution(visitor)
          # NOTE: similar convention as in AR (but no base substitution type) :
          # class BindSubstitution < ::Arel::Visitors::ToSql
          #   include ::Arel::Visitors::BindVisitor
          # end
          return const_get(:BindSubstitution) if const_defined?(:BindSubstitution)

          @@bind_substitutions ||= Java::JavaUtil::HashMap.new
          unless bind_visitor = @@bind_substitutions.get(visitor)
            @@bind_substitutions.synchronized do
              unless @@bind_substitutions.get(visitor)
                bind_visitor = Class.new(visitor) do
                  include ::Arel::Visitors::BindVisitor
                end
                @@bind_substitutions.put(visitor, bind_visitor)
              end
            end
            bind_visitor = @@bind_substitutions.get(visitor)
          end
          bind_visitor
        end

        begin
          require 'arel/visitors/bind_visitor'
        rescue LoadError # AR-3.0
          def bind_substitution(visitor); visitor; end
        end

      end

      if defined? ::Arel::Visitors::VISITORS

        # Instantiates a new AREL visitor for this adapter.
        # @note On `ActiveRecord` **2.3** this method won't be used.
        def new_visitor
          visitor = self.class.resolve_visitor_type(config)
          ( prepared_statements? ? visitor : bind_substitution(visitor) ).new(self)
        end
        protected :new_visitor

        def bind_substitution(visitor); self.class.bind_substitution(visitor); end
        private :bind_substitution

        # @override ActiveRecord's convention
        def unprepared_visitor
          # super does self.class::BindSubstitution.new self
          # we do not require the BindSubstitution constant - auto-generated :
          visitor = self.class.resolve_visitor_type(config)
          bind_substitution(visitor).new(self)
        end

      else # NO-OP when no AREL (AR-2.3)

        # @private documented above
        def new_visitor; end

      end

    end
  end
end