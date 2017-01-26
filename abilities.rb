class Abilities
  def self.create_schema(client)
    client.query("DROP TABLE IF EXISTS rels")
    client.query <<-SQL
      CREATE TABLE rels (
        id INT UNSIGNED NOT NULL,
        parent_id INT UNSIGNED,
        group_id INT,
        path_string varbinary(4069),
        PRIMARY KEY (id),
        INDEX `path_string_ix` (`path_string`(767))
      );
    SQL

    # We need a sequence table, so we can break the path_string into chars
    client.query("DROP TABLE IF EXISTS sequence")
    client.query("CREATE TABLE sequence (id INT NOT NULL);")
    1.upto(767) do |i|
      client.query "INSERT INTO sequence VALUES (#{i});"
    end

    client.query("DROP TABLE IF EXISTS abilities")
    client.query <<-SQL
      CREATE TABLE abilities (
        id INT NOT NULL AUTO_INCREMENT,
        actor_id INT,
        actor_type VARCHAR(255),
        subject_id INT,
        subject_type VARCHAR(255),
        PRIMARY KEY (id)
      );
    SQL
  end

  def initialize(mysql)
    @client = mysql
  end

  # max UNSIGNED INT
  def random_id; Random.rand(4294967295); end

  def add(actor, subject)
    @client.query("INSERT INTO abilities (actor_id, actor_type, subject_id, subject_type) VALUES (#{actor.id}, '#{actor.type}', #{subject.id}, '#{subject.type}')")
  end

  def add_group(group, parent_id = nil)
    id = random_id() # we force a random ID here to work with big numbers. IRL we would just use an AUTO_INCREMENT
    @client.query("INSERT INTO rels (id, group_id, parent_id, path_string) VALUES (#{id}, '#{group.id}', (select t1.id from rels as t1 where t1.group_id='#{parent_id}'), IFNULL((select CONCAT(t2.path_string, '/', hex(#{id})) from rels as t2 where t2.group_id='#{parent_id}'), hex(#{id})))")
  end

  def all_from(from, to_type)
    results = @client.query <<-SQL
    SELECT ab.subject_id
    FROM rels as r1
    JOIN abilities as ab ON ab.actor_id = r1.group_id
    WHERE ab.subject_type = '#{to_type}'
    AND hex(r1.id) IN (
    SELECT
      CASE WHEN SUBSTRING(CONCAT('/', path_string, '/') from s1.id for 1) = '/'
      THEN SUBSTRING(CONCAT('/', path_string, '/')
        from (s1.id + 1)
        FOR LOCATE('/', CONCAT('/', path_string, '/'), s1.id + 1) - s1.id - 1)
      ELSE NULL
    END as paths
    from sequence as s1, rels
    where s1.id between 1 AND CHAR_LENGTH(CONCAT('/', path_string, '/')) - 1
    AND substring(concat('/', path_string, '/') from s1.id for 1) = '/'
    and rels.group_id IN (SELECT subject_id from abilities where subject_type = 'Team'
                         AND actor_type='User' AND actor_id=#{from.id})
    )
    SQL
    results.each(:as => :array).map(&:first)
  end

  def all_subgroups(group)
    results = @client.query <<-SQL
      SELECT A.group_id
      FROM rels A
      JOIN rels B ON A.path_string like concat(B.path_string, '/%')
      where B.group_id = '#{group.id}';
      SQL
    results.each(:as => :array).map(&:first)
  end
end
