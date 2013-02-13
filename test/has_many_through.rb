require 'models/rights_and_roles'

module HasManyThroughMethods
  
  def setup
    CreateRightsAndRoles.up
  end

  def teardown
    CreateRightsAndRoles.down
  end

  def test_has_many_through
    admin_role    = Role.create :name => "Administrator", 
        :description => "System defined super user - access to right and role management."
    admin_role.save!

    assert_equal(0, admin_role.rights.sum(:hours))

    role_rights   = Right.create :name => "Administrator - Full Access To Roles", 
        :actions => "*", :controller_name => "Admin::RolesController", :hours => 0
    right_rights  = Right.create :name => "Administrator - Full Access To Rights", 
        :actions => "*", :controller_name => "Admin::RightsController", :hours => 1.5

    admin_role.rights << role_rights
    admin_role.rights << right_rights
    admin_role.save!

    assert_equal(1.5, admin_role.rights.sum(:hours))
    
    rights_only_role = Role.create! :name => "Rights Manager", 
      :description => "access to rights management"
    rights_only_role.rights << right_rights
    rights_only_role.save!
    rights_only_role.reload
    
    assert admin_role.has_right?(right_rights)
    assert rights_only_role.has_right?(right_rights)
    assert admin_role.reload.has_right?(role_rights)
    assert ! rights_only_role.has_right?(role_rights)
  end
  
end
