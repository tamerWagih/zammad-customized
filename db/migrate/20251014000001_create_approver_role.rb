class CreateApproverRole < ActiveRecord::Migration[7.2]
  def up
    return if Role.exists?(name: 'Approver')

    # Create the Approver role
    Role.create_if_not_exists(
      id:                4,
      name:              'Approver',
      note:              'Can approve or reject ticket approval requests',
      preferences:       {},
      default_at_signup: false,
      updated_by_id:     1,
      created_by_id:     1
    )

    # Add necessary permissions for Approver role
    approver_role = Role.find_by(name: 'Approver')
    
    if approver_role
      # Approvers should be able to view and update tickets they're assigned to approve
      permissions = [
        'ticket.agent',        # Can access agent interface
        'user_preferences',    # Can manage own preferences
        'user_preferences.password', # Can change password
        'user_preferences.language', # Can change language
        'user_preferences.notifications', # Can manage notifications
        'user_preferences.out_of_office', # Can set out of office
        'user_preferences.avatar'  # Can change avatar
      ]
      
      permissions.each do |permission_name|
        permission = Permission.find_by(name: permission_name)
        if permission && !approver_role.permissions.include?(permission)
          approver_role.permissions << permission
        end
      end
      
      approver_role.save!
    end
  end

  def down
    role = Role.find_by(name: 'Approver')
    role&.destroy
  end
end

