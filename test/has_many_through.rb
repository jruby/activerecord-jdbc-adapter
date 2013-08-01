require 'models/rights_and_roles'

module HasManyThroughMethods

  def setup
    CreateRightsAndRoles.up
  end

  def teardown
    CreateRightsAndRoles.down
  end

  def test_has_many_through
    admin_role = Role.create! :name => "Administrator",
      :description => "super user - access to right and role management"

    assert_equal(0, admin_role.rights.sum(:hours))

    role_rights  = Right.create :name => "Administrator - Full Access To Roles",
      :actions => "*", :controller_name => "Admin::RolesController", :hours => 0
    right_rights = Right.create :name => "Administrator - Full Access To Rights",
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

  def test_has_many_select_rows_with_relation
    role = Role.create! :name => "main", :description => "main role"
    Role.create! :name => "user", :description => "user role"

    Right.create! :name => "r0", :hours => 0
    r1 = Right.create! :name => "r1", :hours => 1
    r2 = Right.create! :name => "r2", :hours => 2
    Right.create! :name => "r3", :hours => 3

    role.permission_groups.create! :right => r1.reload
    role.permission_groups.create! :right => r2.reload

    connection = ActiveRecord::Base.connection
    groups = role.reload.permission_groups.select('right_id')

    pend "seems to fail with MRI the same way as with JRuby!" if ar_version('4.0')

    if ar_version('3.1')
      assert_equal [ r1.id, r2.id ], connection.select_values(groups)
    else # 3.0 does not to to_sql in select_values(sql)
      assert_equal [ r1.id, r2.id ], connection.select_values(groups.to_sql)
    end

    result = connection.select(groups.to_sql)
    assert_equal [ r1.id, r2.id ], result.map { |row| row.values.first }

  end if Test::Unit::TestCase.ar_version('3.0')

end
