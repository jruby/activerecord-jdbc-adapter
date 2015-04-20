module XmlColumnTestMethods

  def self.included(base)
    base.send :include, TestMethods if base.ar_version('3.1')
  end

  class XmlModel < ActiveRecord::Base; end

  module TestMethods

    def test_create_xml_column
      create_xml_models! do |t|
        skip('TableDefinition#xml not-implemented') unless t.respond_to?(:xml)
      end

      xml_column = connection.columns(:xml_models).detect do |c|
        c.name == "xml_col"
      end

      assert_xml_type xml_column.sql_type
    ensure
      drop_xml_models! rescue false
    end

    def test_use_xml_column
      if created = ( ( create_xml_models! || true ) rescue nil )

        XmlModel.create! :xml_col => "<xml><LoVE><![CDATA[Rubyist's <3 XML!]]></LoVE></xml>"

        assert xml_model = XmlModel.first

        unless xml_sql_type =~ /text/i
          require 'rexml/document'
          doc = REXML::Document.new xml_model.xml_col
          assert_equal "Rubyist's <3 XML!", doc.root.elements.first.text
        end

        xml_model.xml_col = nil
        xml_model.save!

        assert_nil xml_model.reload.xml_col

        yield if block_given?

      else
        skip('TableDefinition#xml not-implemented')
      end
    ensure
      drop_xml_models! if created
    end

    protected

    def assert_xml_type sql_type
      assert_equal xml_sql_type, sql_type
    end

    def xml_sql_type
      'text'
    end

    private

    def create_xml_models!
      connection.create_table(:xml_models) do |t|
        yield(t) if block_given?
        t.xml :xml_col
      end
    end

    def drop_xml_models!
      disable_logger(connection) do
        connection.drop_table(:xml_models)
      end
    end

  end

end