#!/bin/bash

echo "=== DIAGNOSTIC FOR USER #689 ==="
echo ""

# 1. Check backend logs for User #689
echo "1. BACKEND ACCESS LOGS FOR USER #689:"
docker logs zammad-docker-compose-master-zammad-railsserver-1 2>&1 | grep -E "\[ACCESS\].*User #689" | tail -50

echo ""
echo "2. RAILS CONSOLE CHECKS:"
echo "Run: docker compose exec zammad-railsserver rails c"
echo ""
echo "Then paste this Ruby code:"
echo "----------------------------------------"
cat << 'RUBY'

# Get User #689 details
u = User.find(689)
puts "\n=== USER #689: #{u.login} ==="
puts "Email: #{u.email}"
puts "Roles: #{u.roles.pluck(:name)}"

# Check groups and access levels
puts "\n=== GROUP MEMBERSHIP ==="
puts "All groups: #{u.groups.pluck(:id, :name)}"
puts "Read access groups: #{u.group_ids_access('read')}"
puts "Change access groups: #{u.group_ids_access('change')}"
puts "Full access groups: #{u.group_ids_access('full')}"

# Check created tickets
puts "\n=== CREATED TICKETS ==="
created_tickets = Ticket.where(created_by_id: 689).order(id: :desc).limit(5)
created_tickets.each do |t|
  group = Group.find(t.group_id)
  in_group = u.groups.pluck(:id).include?(t.group_id)
  puts "Ticket ##{t.id}: Group='#{group.name}' (ID:#{t.group_id}), User in group? #{in_group}"
end

# Check ticket #675 (SHARE)
puts "\n=== TICKET #675 (SHARE) ==="
t675 = Ticket.find(675)
puts "Group: #{Group.find(t675.group_id).name} (ID: #{t675.group_id})"
puts "User #689 in this group? #{u.groups.pluck(:id).include?(t675.group_id)}"
puts "Shares: #{t675.shares.active_current.count}"
t675.shares.active_current.each do |s|
  shared_group = Group.find(s.group_id)
  puts "  Shared with: #{shared_group.name} (ID: #{s.group_id})"
  puts "  User #689 in shared group? #{u.groups.pluck(:id).include?(s.group_id)}"
end

# Check ticket #701 (CREATOR - MISSING)
puts "\n=== TICKET #701 (CREATOR - MISSING) ==="
begin
  t701 = Ticket.find(701)
  group = Group.find(t701.group_id)
  puts "Exists: YES"
  puts "Group: #{group.name} (ID: #{t701.group_id})"
  puts "Created by: User ##{t701.created_by_id}"
  puts "User #689 in ticket's group? #{u.groups.pluck(:id).include?(t701.group_id)}"
  puts "User #689 created it? #{t701.created_by_id == 689}"
rescue => e
  puts "Exists: NO - #{e.message}"
end

# Check BaseScope query
puts "\n=== BASESCOPE QUERY SIMULATION ==="
group_ids = u.group_ids_access('read')
puts "group_ids_access('read'): #{group_ids.inspect}"
puts "Is empty? #{group_ids.empty?}"

if group_ids.empty?
  puts "⚠️  WARNING: Empty group_ids will cause SQL issues!"
  puts "   SQL will be: WHERE group_id IN ([]) OR ..."
  puts "   This might exclude created tickets!"
end

RUBY
echo "----------------------------------------"
