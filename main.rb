require 'mysql2'
require_relative 'abilities'
require_relative 'models'

client = Mysql2::Client.new(host: "localhost", username: "root", database: "test")
Record.setup(client)

Record.models.each { |m| m.create_schema }
Abilities.create_schema(client)

abilities = Abilities.new client

arthurnn = User.create 'arthurnn'
zerowidth = User.create 'zerowidth'
bot = User.create 'github-bot'

parent = Team.create 'employees'
platform = Team.create 'platform'
pdata = Team.create 'platform-data'
ha = Team.create 'HA'
rails_upgrade = Team.create 'rails-upgrade'

# User can act in a Team
abilities.add(bot, platform)
abilities.add(arthurnn, pdata)
abilities.add(arthurnn, rails_upgrade)
abilities.add(zerowidth, ha)

# Team can act in a Repository
abilities.add(parent, Repository.create('docs'))
abilities.add(platform, Repository.create('github'))
abilities.add(pdata, Repository.create('platform-data'))
abilities.add(ha, Repository.create('ha-secrety-repo'))
abilities.add(rails_upgrade, Repository.create('rails'))

# Add Groups(Teams)
abilities.add_group(parent)
abilities.add_group(platform, parent)
abilities.add_group(pdata, platform)
abilities.add_group(ha, platform)
abilities.add_group(rails_upgrade, platform)

puts "All repos arthurnn can see:"
abilities.all_from(arthurnn, 'Repository').each do |id|
  puts Repository.find(id)
end
random_team = nil
# max deepth is 85 = 765 / (1 + (4bytes INT * 8bits / 4bits(HEX size)))
1.upto(85) do |v|
  t = Team.create("gen#{v}")
  abilities.add_group(t, parent)
  parent = t
  random_team = t if v == 50
end

# add a random repo, in the middle of the stack of teams
abilities.add(random_team, Repository.create('random-repo'))

abilities.add(parent, Repository.create('low-repo'))
abilities.add(u = User.create('low-level-user'), parent)

puts "\nAll repos 'low-level-user can see:"
abilities.all_from(u, 'Repository').each do |id|
  puts Repository.find(id)
end

puts "\nAll sub-teams of platform:"
abilities.all_subgroups(platform).each do |id|
  puts Team.find(id)
end
