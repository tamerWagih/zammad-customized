namespace :zammad do
  desc 'Insert development sample data for organizations, groups, and users (idempotent)'
  task dev_sample_data: :environment do
    puts 'Seeding development sample data...'

    ActiveRecord::Base.transaction do
      # Organizations
      techcorp = Organization.find_or_create_by!(name: 'TechCorp Solutions') do |o|
        o.note = 'Technology company'
      end

      supportpro = Organization.find_or_create_by!(name: 'SupportPro Inc') do |o|
        o.note = 'Support services company'
      end

      # Groups
      support_agents = Group.find_or_create_by!(name: 'Support Agents') do |g|
        g.active = true
      end

      managers = Group.find_or_create_by!(name: 'Managers') do |g|
        g.active = true
      end

      # Roles
      agent_role    = Role.find_by(name: 'Agent')
      customer_role = Role.find_by(name: 'Customer')
      admin_role    = Role.find_by(name: 'Admin')

      raise 'Required roles not found (Agent/Customer)' unless agent_role && customer_role

      def ensure_role(user, role)
        return if user.roles.exists?(id: role.id)
        user.roles << role
      end

      def ensure_group_access(user, group, access)
        # Merge existing access map with requested one
        existing = user.group_names_access_map
        existing[group.name] ||= []
        existing[group.name] = (Array(existing[group.name]) | [access]).uniq
        user.group_names_access_map = existing
      end

      # Agent: Sarah Johnson (TechCorp)
      sarah = User.find_or_initialize_by(email: 'sarah.johnson@techcorp.com')
      sarah.login      ||= 'sarah.johnson'
      sarah.firstname  = 'Sarah'
      sarah.lastname   = 'Johnson'
      sarah.active     = true
      sarah.organization = techcorp
      sarah.password   = 'password123' if sarah.new_record? || sarah.encrypted_password.blank?
      sarah.save!
      ensure_role(sarah, agent_role)
      ensure_group_access(sarah, support_agents, 'full')

      # Agent: Mike Chen (SupportPro)
      mike = User.find_or_initialize_by(email: 'mike.chen@supportpro.com')
      mike.login      ||= 'mike.chen'
      mike.firstname  = 'Mike'
      mike.lastname   = 'Chen'
      mike.active     = true
      mike.organization = supportpro
      mike.password   = 'password123' if mike.new_record? || mike.encrypted_password.blank?
      mike.save!
      ensure_role(mike, agent_role)
      ensure_group_access(mike, support_agents, 'full')
      ensure_group_access(mike, managers, 'full')

      # Customer: Alice Williams (TechCorp)
      alice = User.find_or_initialize_by(email: 'alice.williams@techcorp.com')
      alice.login      ||= 'alice.williams'
      alice.firstname  = 'Alice'
      alice.lastname   = 'Williams'
      alice.active     = true
      alice.organization = techcorp
      alice.password   = 'customer123' if alice.new_record? || alice.encrypted_password.blank?
      alice.save!
      ensure_role(alice, customer_role)

      # Customer: Bob Rodriguez (SupportPro)
      bob = User.find_or_initialize_by(email: 'bob.rodriguez@supportpro.com')
      bob.login      ||= 'bob.rodriguez'
      bob.firstname  = 'Bob'
      bob.lastname   = 'Rodriguez'
      bob.active     = true
      bob.organization = supportpro
      bob.password   = 'customer123' if bob.new_record? || bob.encrypted_password.blank?
      bob.save!
      ensure_role(bob, customer_role)
    end

    puts 'Development sample data ensured.'
    puts '- Organizations: TechCorp Solutions, SupportPro Inc'
    puts '- Groups: Support Agents, Managers'
    puts '- Agent Users: sarah.johnson@techcorp.com, mike.chen@supportpro.com'
    puts '- Customer Users: alice.williams@techcorp.com, bob.rodriguez@supportpro.com'
  end
end


