require 'minitest/autorun'
require 'mysql2'
require_relative 'abilities'
require_relative 'models'

class AbilitiesTest < Minitest::Test
  def setup
    client = Mysql2::Client.new(host: "localhost", username: "root", database: "test")
    Record.setup(client)
    Record.models.each { |m| m.create_schema }
    Abilities.create_schema(client)

    @abilities = Abilities.new client

    # create a few users
    @arthurnn = User.create 'arthurnn'
    @zerowidth = User.create 'zerowidth'
    @jesseplusplus = User.create 'jesseplusplus'
    @rocio = User.create 'rocio'
    @bot = User.create 'github-bot'

    # create some teams
    @parent = Team.create 'employees'
    @platform = Team.create 'platform'
    @design = Team.create 'design'
    @pdata = Team.create 'platform-data'
    @ha = Team.create 'HA'
    @rails_upgrade = Team.create 'rails-upgrade'
    @abilities.add_group(@parent)
    @abilities.add_group(@platform, @parent)
    @abilities.add_group(@pdata, @platform)
    @abilities.add_group(@ha, @platform)
    @abilities.add_group(@rails_upgrade, @platform)

    @abilities.add(@arthurnn, @pdata)
    @abilities.add(@arthurnn, @rails_upgrade)
    @abilities.add(@zerowidth, @ha)
    @abilities.add(@jesseplusplus, @platform)
    @abilities.add(@rocio, @pdata)
    @abilities.add(@bot, @parent)
  end

  def test_3_level_subteams
    @repo_pdata = Repository.create('platform-data')
    @abilities.add(@pdata, @repo_pdata)

    assert_includes @abilities.all_from(@arthurnn, 'Repository'), @repo_pdata.id
    assert_includes @abilities.all_from(@rocio, 'Repository'), @repo_pdata.id

    refute_includes @abilities.all_from(@zerowidth, 'Repository'), @repo_pdata.id
    refute_includes @abilities.all_from(@jesseplusplus, 'Repository'), @repo_pdata.id
  end

  def test_a_very_deep_tree
    parent, random_team = @parent, nil
    # max deepth is 85 = 765 / (1 + (4bytes INT * 8bits / 4bits(HEX size)))
    1.upto(85) do |v|
      t = Team.create("gen#{v}")
      @abilities.add_group(t, parent)
      parent = t
      random_team = t if v == 50
    end

    repo = Repository.create('random-repo')
    # add a random repo, in the middle of the stack of teams
    @abilities.add(random_team, repo)

    @abilities.add(parent, low_repo = Repository.create('low-repo'))
    @abilities.add(u = User.create('low-level-user'), parent)

    assert_includes @abilities.all_from(u, 'Repository'), repo.id
    assert_includes @abilities.all_from(u, 'Repository'), low_repo.id

    @abilities.add(@design, repo_design = Repository.create('design'))
    refute_includes @abilities.all_from(u, 'Repository'), repo_design.id
  end

  def test_all_subteams
    sub_teams = @abilities.all_subgroups(@platform)

    assert_includes sub_teams, @pdata.id
    assert_includes sub_teams, @ha.id
    refute_includes sub_teams, @design.id
  end

  def test_user_with_two_teams
    rails = Repository.create('rails')
    @abilities.add(@rails_upgrade, rails)
    repo_pdata = Repository.create('platform-data')
    @abilities.add(@pdata, repo_pdata)

    assert_includes @abilities.all_from(@arthurnn, 'Repository'), repo_pdata.id
    assert_includes @abilities.all_from(@arthurnn, 'Repository'), rails.id
  end

  def test_move_group
    @abilities.add(@design, repo_design = Repository.create('design'))
    repo_pdata = Repository.create('platform-data')
    @abilities.add(@pdata, repo_pdata)

    @abilities.move_group(@pdata, @design)

    assert_includes @abilities.all_from(@arthurnn, 'Repository'), repo_design.id
    refute_includes @abilities.all_from(@arthurnn, 'Repository'), repo_pdata.id
  end
end
