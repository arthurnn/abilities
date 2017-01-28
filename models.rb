class Record
  attr_accessor :id, :name

  def self.inherited(subclass)
    @@models ||= []
    @@models << subclass
  end
  def self.setup(mysql)
    @@models.each { |m| m.mysql = mysql }
  end
  def self.models
    @@models
  end

  def self.create_schema
    @@mysql.query("DROP TABLE IF EXISTS #{table_name}")
    @@mysql.query <<-SQL
      CREATE TABLE #{table_name} (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        name VARCHAR(255),
        PRIMARY KEY (id)
      ) AUTO_INCREMENT=4294967295;
    SQL
  end

  def initialize(name)
    self.name = name
  end

  def type; self.class.name; end

  def to_s
    "#{type}(#{name})"
  end

  def self.mysql=(mysql)
    @@mysql = mysql
  end

  def self.create(name)
    entry = self.new(name)
    @@mysql.query("INSERT INTO #{table_name} (name) VALUES ('#{entry.name}')")
    entry.id = @@mysql.last_id
    entry
  end

  def self.find(id)
    results = @@mysql.query("SELECT id, name FROM #{table_name} where id=#{id}")
    data = results.first
    raise "Record not found: '#{id}'" unless data
    entry = new(data['name'])
    entry.id = data['id']
    entry
  end
end
class User < Record
  def self.table_name; 'users'; end
end
class Team < Record
  def self.table_name; 'teams'; end
end
class Repository < Record
  def self.table_name; 'repositories'; end
end
