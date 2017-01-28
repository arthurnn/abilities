class Tree

  class Node
    attr_accessor :id, :parent
  end

  def initialize(mysql)
    @mysql = mysql
  end

  def insert(node)
    if node.parent
      r = @mysql.query "select path_string FROM rels where group_id=#{node.parent.id}"
      path_string = r.each(:as => :array)[0][0]
    else
      path_string = ""
    end
    path_string = PathString.new(path_string).append(node.id).to_s

    sql = "INSERT INTO rels (group_id, parent_id, path_string) VALUES (#{node.id}, #{node.parent ? node.parent.id : 'NULL'}, '#{Mysql2::Client.escape(path_string)}')"
    @mysql.query(sql)
  end

  def subordinates(node_id)
    results = @mysql.query <<-SQL
      SELECT A.group_id
      FROM rels A
      JOIN rels B ON A.path_string like concat(B.path_string, '%')
      where B.group_id = #{node_id};
    SQL
    results.each(:as => :array).map(&:first)
  end

  def parents(node_ids)
    node_ids = Array(node_ids)
    results = @mysql.query <<-SQL
      SELECT path_string
      FROM rels
      WHERE group_id IN (#{node_ids.join(',')})
    SQL

    ids = Set.new
    results.each(:as => :array).each do |row|
      path_string = row[0]
      PathString.new(path_string).each_id { |id| ids << id }
    end
    ids.to_a
  end

  class PathString
    class Encoder
      # input: id int, unsigned 8bytes
      # output: array of bytes
      def self.encode(n)
        a = []
        while n > 0
          a.unshift n % 256
          n /= 256
        end
        while a.size < 8
          a.unshift 0
        end
        a
      end

      # input: array with 8 bytes
      # ouput: id
      def self.decode(bytes)
        a = bytes.dup
        id = 0
        while a.size > 0
          id += a.pop * (256 ** (7 - a.size))
        end
        id
      end
    end

    def initialize(string)
      @s = string
    end

    def append(id)
      @s += Encoder.encode(id).pack('C8')
    end

    def to_s
      @s
    end

    def each_id
      @s.unpack('C*').each_slice(8) do |bytes|
        yield Encoder.decode(bytes)
      end
    end
  end
end
