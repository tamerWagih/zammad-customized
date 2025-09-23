# frozen_string_literal: true

# Development sample data seeder (idempotent)

ActiveRecord::Base.logger = nil

ActiveRecord::Base.transaction do
  techcorp   = Organization.find_or_create_by!(name: 'TechCorp Solutions') { |o| o.note = 'Technology company' }
  supportpro = Organization.find_or_create_by!(name: 'SupportPro Inc')    { |o| o.note = 'Support services company' }

  support_agents = Group.find_or_create_by!(name: 'Support Agents') { |g| g.active = true }
  managers       = Group.find_or_create_by!(name: 'Managers')       { |g| g.active = true }

  agent_role    = Role.find_by(name: 'Agent')
  customer_role = Role.find_by(name: 'Customer')
  raise 'Missing base roles (Agent/Customer)' unless agent_role && customer_role

  def ensure_roles(user, roles)
    roles.each { |r| user.roles << r unless user.roles.exists?(id: r.id) }
  end

  def ensure_group_access(user, map)
    current = user.group_names_access_map
    map.each do |name, access|
      arr = Array(current[name])
      arr |= Array(access)
      current[name] = arr
    end
    user.group_names_access_map = current
  end

  sarah = User.find_or_initialize_by(email: 'sarah.johnson@techcorp.com')
  sarah.login        ||= 'sarah.johnson'
  sarah.firstname      = 'Sarah'
  sarah.lastname       = 'Johnson'
  sarah.active         = true
  sarah.organization   = techcorp
  sarah.password       = 'password123'
  sarah.save!
  ensure_roles(sarah, [agent_role])
  ensure_group_access(sarah, { 'Support Agents' => 'full' })

  mike = User.find_or_initialize_by(email: 'mike.chen@supportpro.com')
  mike.login         ||= 'mike.chen'
  mike.firstname       = 'Mike'
  mike.lastname        = 'Chen'
  mike.active          = true
  mike.organization    = supportpro
  mike.password        = 'password123'
  mike.save!
  ensure_roles(mike, [agent_role])
  ensure_group_access(mike, { 'Support Agents' => 'full', 'Managers' => 'full' })

  alice = User.find_or_initialize_by(email: 'alice.williams@techcorp.com')
  alice.login        ||= 'alice.williams'
  alice.firstname      = 'Alice'
  alice.lastname       = 'Williams'
  alice.active         = true
  alice.organization   = techcorp
  alice.password       = 'customer123'
  alice.save!
  ensure_roles(alice, [customer_role])

  bob = User.find_or_initialize_by(email: 'bob.rodriguez@supportpro.com')
  bob.login          ||= 'bob.rodriguez'
  bob.firstname        = 'Bob'
  bob.lastname         = 'Rodriguez'
  bob.active           = true
  bob.organization     = supportpro
  bob.password         = 'customer123'
  bob.save!
  ensure_roles(bob, [customer_role])
end

puts 'Seed complete.'

