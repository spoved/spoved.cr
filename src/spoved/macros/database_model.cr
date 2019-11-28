macro database_model(table, primary_id, columns, use_expire = false)

  {% if use_expire %}
    private property is_expired : Bool
  {% end %}

  def initialize(
      {% for name, val in columns %}
        {% if val.id == "UUID" || val.id == "JSON::Any" %}
          {{name}} : String,
        {% else %}
          {{name}} : {{val}},
        {% end %}
      {% end %}
      {% if use_expire %}
        @is_expired = false
      {% end %}
    )
    {% for name, val in columns %}
      {% if val.id == "UUID" %}
        @{{name}} = UUID.new({{name}})
      {% elsif val.id == "JSON::Any" %}
        @{{name}} = JSON.parse({{name}})
      {% else %}
      @{{name}} = {{name}}
      {% end %}
    {% end %}
  end

  {% for name, val in columns %}
    # Set our class properites here
    property {{name}} : {{val}}

    # Create helper and translation functions
    {% if val.id == "UUID" %}
      def {{name}}=(val : String)
        self.{{name}} = UUID.new(val)
      end

      def _{{name}}_for_mysql
        {{name}}.to_s
      end
    {% elsif val.id == "JSON::Any" %}
      def {{name}}=(val : String)
        self.{{name}} = JSON.parse(val)
      end

      def _{{name}}_for_mysql
        {{name}}.to_json
      end
    {% else %}
      def _{{name}}_for_mysql
        {{name}}
      end
    {% end %}
  {% end %}

  {% if use_expire %}
    EXPIRE_WHERE_EXCLUDE = " start_time <= NOW() AND (end_time > NOW() OR end_time = 0) "
    EXPIRE_DELETE = " end_time = NOW() "
    EXPIRE_WHERE_SELECT = " start_time <= NOW() AND (end_time <= NOW() AND end_time != 0) "
  {% end %}

  RES_STRUCTURE = {
      {% for name, val in columns %}
        {% if val.id == "UUID" || val.id == "JSON::Any" %}
          {{name}}: String,
        {% else %}
          {{name}}: {{val}},
        {% end %}
      {% end %}
    }

  # Alias of each `key => typeof(val)` in a `NamedTuple`
  alias NamedVars = NamedTuple(
    {% for name, val in columns %}
      {% if val.id == "UUID" || val.id == "JSON::Any" %}
        {{name}}: String,
      {% else %}
        {{name}}: {{val}},
      {% end %}
    {% end %}
  )

  # Alias of each `typeof(val)` in a `Tuple`
  alias Vars = Tuple(
    {% for name, val in columns %}
      {% if val.id == "UUID" || val.id == "JSON::Any" %}
        String,
      {% else %}
        {{val}},
      {% end %}
    {% end %}
  )

  # All the possible `typeof(val)` for each property
  alias ValTypes = String {% for name, val in columns %} | {{val}} {% end %}

  def primary_key_value
    self.{{primary_id.id}}
  end

  private def db
    self.class.db
  end

  # The database table name
  protected def self.table_name : String
    {{table.id.stringify}}
  end

  # The column which holds the primary key for the record
  protected def self.primary_key_name : String
    {{ primary_id.id.stringify }}
  end

  # Array of all the column names
  protected def self.columns : Array(String)
    {{ columns.keys.map &.stringify }}
  end

  # Array of all the column names except for the primary id
  protected def self.non_id_columns
    {{ @type }}.columns.reject &.== {{ @type }}.primary_key_name
  end

  # Will convert the `{{@type}}::NamedVars` into an object
  protected def self.from_named_truple(res : NamedVars {% if use_expire %}, expired : Bool = false {% end %}) : {{ @type }}
    {{@type}}.new(
      {% for name, val in columns %}
        {{name}}: res[:{{name}}],
      {% end %}
      {% if use_expire %}
      is_expired: expired,
      {% end %}
    )
  end

  # Will convert the `{{@type}}::NamedVars` into an object
  protected def self.from_data_hash(data_hash : DataHash)

    new_hash = Hash(Symbol, JSON::Any).new

    data_hash.each do |%key, %value|
      case %key
      {% for name, val in columns %}
      when {{name.stringify}}
        new_hash[:{{name}}] = JSON::Any.new %value
      {% end %}
      end
    end
    new_hash.to_json
  end

  # Gather all records from the database
  private def self._query_all(
    where = "",
    {% if use_expire %}
      expired = false
    {% end %}
    )

    {% if use_expire %}
      if expired
        where = "WHERE #{EXPIRE_WHERE_SELECT}"
      end

      if where == ""
        where =  "WHERE #{EXPIRE_WHERE_EXCLUDE}"
      end
    {% end %}

    sql = "SELECT `#{{{@type}}.columns.join("`,`")}` FROM `#{self.table_name}` #{where}"
    db.query_all(sql, as: RES_STRUCTURE)
  end

  # Return an array containing all of the `{{@type}}` records
  def self.all : Array({{@type}})
    self._query_all.map{ |x| {{@type}}.from_named_truple(x) }
  rescue ex
    logger.error(ex)
    Array({{@type}}).new
  end

  # Queries for all records and yields each one
  def self.each(&block)
    self.all do |x|
       yield x
    end
  end

  def self.query(
    {% for name, val in columns %}
      {{name}} : {{val}}? = nil,
    {% end %}
    {% if use_expire %}
      expired = false
    {% end %}
  )

    subs = {
      '"'  => "\\\"",
    }
    where = String.build do |io|
      io << "WHERE "
      {% for name, val in columns %}
        unless {{name}}.nil?
          io << "`{{name}}` = "
        {% if val.id == "UUID" %}
          io << "'" << {{name}}.to_s << "'"
        {% elsif val.id == "JSON::Any" %}
        {% elsif val.id == "String" %}
          io << "\"" << {{name}}.to_s.gsub(subs) << "\""
        {% else %}
          io << "\"" << {{name}}.to_s.gsub(subs) << "\""
        {% end %}
          io << " AND "
        end
      {% end %}

      {% if use_expire %}
        if expired
          io << EXPIRE_WHERE_SELECT
        else
          io << EXPIRE_WHERE_EXCLUDE
        end
      {% end %}
    end
    logger.debug(where.chomp(" AND "), "{{@type}}.query")

    self._query_all(where.chomp(" AND ")).map{ |x| {{@type}}.from_named_truple(x {% if use_expire %}, expired {% end %}) }
  end

  # Find a single record based on primary key
  def self.find(id) : {{@type}}?
    {% if use_expire %}
    sql = "SELECT `#{{{@type}}.columns.join("`,`")}` FROM `#{self.table_name}` "\
      "WHERE `#{self.primary_key_name}` = ? AND #{EXPIRE_WHERE_EXCLUDE}"
    {% else %}
    sql = "SELECT `#{{{@type}}.columns.join("`,`")}` FROM `#{self.table_name}` "\
      "WHERE `#{self.primary_key_name}` = ?"
    {% end %}

    logger.debug(sql, "self.find")
    res = db.query_one(sql, id, as: RES_STRUCTURE)

    {{@type}}.from_named_truple(res)
  rescue ex
    logger.error(ex, "self.find")
    nil
  end

  private def _delete_record
    {% if use_expire %}
      sql = "UPDATE `#{ {{@type}}.table_name }` "\
        "SET #{EXPIRE_DELETE} "\
        "WHERE `#{{{@type}}.primary_key_name}` = ?"
    {% else %}
      sql = "DELETE FROM `#{ {{@type}}.table_name }` "\
        "WHERE `#{{{@type}}.primary_key_name}` = ?"
    {% end %}

    logger.debug(sql)
    db.exec(sql, _{{primary_id.id}}_for_mysql)
    {% if use_expire %}
      @is_expired = true
    {% end %}
  end

  {% if use_expire %}
  # TODO: Validate this behavior
  private def _unexpire_record
    if {{@type}}.query(uuid: self.uuid).empty?
      false
    else
      sql = "UPDATE `#{ {{@type}}.table_name }` "\
        "SET end_time = 0 "\
        "WHERE `#{{{@type}}.primary_key_name}` = ?"
      logger.debug(sql)
      db.exec(sql, _{{primary_id.id}}_for_mysql)
      true
    end
  rescue ex
    logger.error(ex, "_unexpire_record")
    false
  end
  {% end %}

  private def _insert_record
    %cols = {{@type}}.columns.map {|x| "`#{x}` = ?"}

    {% if use_expire %}
    return _update_record if _unexpire_record
    {% end %}

    sql = "INSERT INTO `#{ {{@type}}.table_name }` SET #{%cols.join(",")}"
    logger.debug(sql)
    db.exec(sql,
      {% for key in columns.keys %}
      _{{key}}_for_mysql ,
      {% end %}
    )
  end

  private def _update_record
    %cols = {{@type}}.non_id_columns.map {|x| "`#{x}` = ?"}

    sql = "UPDATE `#{{{@type}}.table_name}` SET #{%cols.join(",")} "\
      "WHERE `#{{{@type}}.primary_key_name}` = ?"

    logger.debug(sql)
    db.exec(sql,
      {% for key in columns.keys.reject { |x| x.id == primary_id.id } %}
      _{{key}}_for_mysql ,
      {% end %}
      _{{primary_id.id}}_for_mysql
    )
  end

  def get(%name : Symbol | String) : ValTypes
    case %name.to_s
    {% for name, val in columns %}{% if name.id != primary_id.id %}
    when {{name.stringify}}
      self.{{name}}
    {% end %}{% end %}
    else
      raise "Could not get |#{%name}|"
    end
  rescue ex
    logger.error(ex)
  end

  def set(%name : Symbol | String, %value : ValTypes)
    # raise "Cant change primary key" if %name.to_s == {{@type}}.primary_key_name
    logger.debug "#{primary_key_value} : setting #{%name} to #{%value}"

    case %name.to_s
    {% for name, val in columns %}{% if name.id != primary_id.id %}
    when {{name.stringify}}
      self.{{name}} = %value
    {% end %}{% end %}
    else
      raise "Could not set |#{%name}|"
    end
  rescue ex
    logger.error(ex)
  end

  def update_attrs(changes : Hash(String | Symbol, ValTypes))
    changes.each do |n, v|
      raise "Unknown column" unless {{@type}}.columns.includes?(n.to_s)
      raise "Cant change primary key" if n.to_s == {{@type}}.primary_key_name

      self.set(n, v)
    end
  end

  def save!
    if self.is_expired
      raise "Cant save expired record!"
    end
    self._insert_record
  end

  def save
    save!
  rescue ex
    logger.error(ex)
  end

  def destroy!
    self._delete_record
  end

  def destroy
    destroy!
  rescue ex
    logger.error(ex)
  end

  def update!
    if self.is_expired
      raise "Cant update expired record!"
    end
    self._update_record
  end

  def update
    update!
  rescue ex
    logger.error(ex)
  end

  def self.create(**args)
    obj = self.new(**args)
    obj.save
    obj
  end
end
