module Granite::ORM::Querying
  macro extended
    macro __process_querying
      \{% primary_name = PRIMARY[:name] %}
      \{% primary_type = PRIMARY[:type] %}

      # Create the from_sql method
      def self.from_sql(result)
        model = \{{@type.name.id}}.new
        model.set_attributes(result)
        model
      end

      def set_attributes(result : DB::ResultSet)
        # Loading from DB means existing records.
        @new_record = false
        \{% for name, type in FIELDS %}
          \{% if type.id.stringify == "Time" %}
            if @@adapter.class.name == "Granite::Adapter::Sqlite"
              # sqlite3 does not have timestamp type - timestamps are stored as str
              # will break for null timestamps
              self.\{{name.id}} = Time.parse(result.read(String), "%F %X" )
            else
              self.\{{name.id}} = result.read(Union(\{{type.id}} | Nil))
            end
          \{% else %}
            self.\{{name.id}} = result.read(Union(\{{type.id}} | Nil))
          \{% end %}
        \{% end %}
        return self
      end
    end
  end

  # Clear is used to remove all rows from the table and reset the counter for
  # the primary key.
  def clear
    @@adapter.clear @@table_name
  end

  # All will return all rows in the database. The clause allows you to specify
  # a WHERE, JOIN, GROUP BY, ORDER BY and any other SQL92 compatible query to
  # your table.  The results will be an array of instantiated instances of
  # your Model class.  This allows you to take full advantage of the database
  # that you are using so you are not restricted or dummied down to support a
  # DSL.
  def all(clause = "", params = [] of DB::Any)
    rows = [] of self
    @@adapter.select(@@table_name, fields, clause, params) do |results|
      results.each do
        rows << from_sql(results)
      end
    end
    return rows
  end

  # First adds a `LIMIT 1` clause to the query and returns the first result
  def first(clause = "", params = [] of DB::Any)
    all([clause.strip, "LIMIT 1"].join(" "), params).first?
  end

  # find returns the row with the primary key specified.
  # it checks by primary by default, but one can pass
  # another field for comparison
  def find(value)
    return find_by(@@primary_name, value)
  end

  # find_by using symbol for field name.
  def find_by(field : Symbol, value)
    find_by(field.to_s, value)
  end

  # find_by returns the first row found where the field maches the value
  def find_by(field : String, value)
    row = nil
    @@adapter.select_one(@@table_name, fields, field.to_s, value) do |result|
      row = from_sql(result) if result
    end
    return row
  end

  def find_each(clause = "", params = [] of DB::Any, batch_size limit = 100, offset = 0)
    find_in_batches(clause, params, batch_size: limit, offset: offset) do |batch|
      batch.each do |record|
        yield record
      end
    end
  end

  def find_in_batches(clause = "", params = [] of DB::Any, batch_size limit = 100, offset = 0)
    if limit < 1
      raise ArgumentError.new("batch_size must be >= 1")
    end

    while true
      results = all "#{clause} LIMIT ? OFFSET ?", params + [limit, offset]
      break unless results.any?
      yield results
      offset += limit
    end
  end

  # count returns a count of all the records
  def count : Int32
    scalar "SELECT COUNT(*) FROM #{quoted_table_name}", &.to_s.to_i
  end

  def exec(clause = "")
    @@adapter.open { |db| db.exec(clause) }
  end

  def query(clause = "", params = [] of DB::Any, &block)
    @@adapter.open { |db| yield db.query(clause, params) }
  end

  def scalar(clause = "", &block)
    @@adapter.open { |db| yield db.scalar(clause) }
  end
end
