require 'test_helper'
require 'db/jdbc_derby_config'

class JdbcPlainTest < Test::Unit::TestCase

  def self.startup
    super
    @_prev_ = ActiveRecord::Base.remove_connection
    ActiveRecord::Base.establish_connection JDBC_DERBY_CONFIG
    define_schema
  end

  def self.shutdown
    drop_schema
    @_prev_ && ActiveRecord::Base.establish_connection(@_prev_)
    super
  end

  def self.define_schema
    ActiveRecord::Schema.define do
      create_table :albums do |table|
        table.column :title, :string
        table.column :performer, :string
      end

      create_table :tracks do |table|
        table.column :album_id, :integer
        table.column :track_number, :integer
        table.column :title, :string
      end
    end
  end

  def self.drop_schema
    connection = ActiveRecord::Base.connection
    connection.drop_table :albums
    connection.drop_table :tracks
  end

  class Album < ActiveRecord::Base
    has_many :tracks
  end

  class Track < ActiveRecord::Base
    belongs_to :album
  end

  test '(schema) works as expected' do
    album = Album.new
    assert album.respond_to?(:title)
    assert album.respond_to?(:title=)
    assert_not_empty Album.columns

    album = Album.create!(:title => 'Black and Blue', :performer => 'The Rolling Stones')
    album.tracks.create(:track_number => 1, :title => 'Hot Stuff')
    album.tracks.create(:track_number => 2, :title => 'Hand Of Fate')
    album.tracks.create(:track_number => 3, :title => 'Cherry Oh Baby ')
    album.tracks.create(:track_number => 4, :title => 'Memory Motel ')
    album.tracks.create(:track_number => 5, :title => 'Hey Negrita')
    album.tracks.create(:track_number => 6, :title => 'Fool To Cry')
    album.tracks.create(:track_number => 7, :title => 'Crazy Mama')
    album.tracks.create(:track_number => 8,:title => 'Melody (Inspiration By Billy Preston)')

    assert_equal 8, Album.find(album.id).tracks.length

    if ar_version('3.1')
      assert_equal "Black and Blue", Album.where(:title => 'Black and Blue').first.title
      assert Track.where(:title => 'Hot Stuff').first.album_id
    else
      assert_equal "Sticky Fingers", Album.find_by_title('Black and Blue').title
      assert Track.find_by_title('Hot Stuff').album_id
    end
  end

end
