class Topic < ActiveRecord::Base
  class StoreDateAsInteger
    def self.dump(value)
      return value.strftime('%Y%0m%0d').to_i if value.respond_to? :strftime
      return value.to_i if value.respond_to? :to_i
      return value.gsub('-', '').gsub('/', '').to_i if value.is_a? String
      0
    end

    def self.load(value)
      Date.strptime(value.to_s, '%Y%m%d') rescue nil
    end
  end

  serialize :content
  serialize :created_on, StoreDateAsInteger
end

class ImportantTopic < Topic
  serialize :important, Hash
end

class TopicMigration < ActiveRecord::Migration

  def self.up
    create_table :topics, :force => true do |t|
      t.string :title
      # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
      # Oracle SELECT WHERE clause which causes many unit test failures
      #if current_adapter?(:OracleAdapter)
        #t.string :content, :limit => 4000
        #t.string :important, :limit => 4000
      #else
        t.text :content
        t.text :important
      #end
      t.integer :created_on
      t.string :type
      t.timestamps :null => false
    end
  end

  def self.down
    drop_table :topics
  end

end
