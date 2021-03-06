require 'set'
require_relative 'tree'

class Abilities
  def self.create_schema(client)
    Tree.create_schema(client)
    client.query("DROP TABLE IF EXISTS abilities")
    client.query <<-SQL
      CREATE TABLE abilities (
        id INT NOT NULL AUTO_INCREMENT,
        actor_id BIGINT,
        actor_type VARCHAR(255),
        subject_id BIGINT,
        subject_type VARCHAR(255),
        PRIMARY KEY (id)
      );
    SQL
  end

  def initialize(mysql)
    @client = mysql
  end

  def add(actor, subject)
    @client.query("INSERT INTO abilities (actor_id, actor_type, subject_id, subject_type) VALUES (#{actor.id}, '#{actor.type}', #{subject.id}, '#{subject.type}')")
  end

  def add_group(group, parent_group = nil)
    tree = Tree.new(@client)
    node = Tree::Node.new
    node.id = group.id
    if parent_group
      node.parent = Tree::Node.new
      node.parent.id = parent_group.id
    end

    tree.insert(node)
  end

  def move_group(group, new_parent)
    tree = Tree.new(@client)
    tree.update_parent(group.id, new_parent.id)
  end

  def all_from(from, to_type)
    results = @client.query <<-SQL
      SELECT subject_id
      FROM abilities
      WHERE subject_type = 'Team'
      AND actor_type = 'User'
      AND actor_id = #{from.id}
    SQL
    team_ids = results.each(:as => :array).map(&:first)

    tree = Tree.new(@client)
    team_ids += tree.parents(team_ids)

    results = @client.query <<-SQL
      SELECT subject_id
      FROM abilities
      WHERE subject_type = '#{to_type}'
      AND actor_type = 'Team'
      AND actor_id IN (#{team_ids.to_a.join(',')})
    SQL
    results.each(:as => :array).map(&:first)
  end

  def all_subgroups(group)
    tree = Tree.new(@client)
    tree.subordinates(group.id)
  end
end
