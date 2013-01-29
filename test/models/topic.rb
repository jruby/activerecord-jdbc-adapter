class Topic < ActiveRecord::Base
  serialize :content
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
      t.string :type
      t.timestamps
    end
  end

  def self.down
    drop_table :topics
  end

end