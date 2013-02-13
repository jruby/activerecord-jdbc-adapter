class CreateRightsAndRoles < ActiveRecord::Migration
  def self.up
    create_table :role_assignments do |t| 
      t.column :role_id, :integer
      t.column :user_id, :integer
    end

    create_table :roles do |t| 
      t.column :name, :string
      t.column :description, :string
    end 

    create_table :permission_groups do |t|
      t.column :right_id, :integer, :null => false
      t.column :role_id, :integer, :null => false
    end 

    create_table :rights do |t| 
      t.column :name, :string
      t.column :controller_name, :string
      t.column :actions, :string
      t.column :hours, :float, :null => false
    end
  end

  def self.down
    drop_table :role_assignments
    drop_table :roles
    drop_table :permission_groups
    drop_table :rights
  end
end

class Right < ActiveRecord::Base
  has_many :permission_groups, :dependent => :destroy
  has_many :roles, :through => :permission_groups
end

class Role < ActiveRecord::Base
  has_many :permission_groups, :dependent => :destroy
  has_many :rights, :through => :permission_groups
  has_many :role_assignments, :dependent => :destroy
  
  def has_right?(right)
    rights.include? right
  end
end

class PermissionGroup < ActiveRecord::Base
  belongs_to :right
  belongs_to :role
end

class RoleAssignment < ActiveRecord::Base
  belongs_to :user
  belongs_to :role
end