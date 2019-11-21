require "db"
require "mysql"

class Spoved::DB::Model::MySQL
  alias DataHash = Hash(String, Array(JSON::Any) | Bool | Float64 | Hash(String, JSON::Any) | Int64 | String | Nil)

  MYSQL_URI = URI.new(
    "mysql",
    ENV["MYSQL_HOST"]? || "localhost",
    ENV["MYSQL_PORT"].to_i || 3306,
    ENV["MYSQL_DB"]? || "",
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || ""
  )

  @@db : DB::Database?

  def self.db : DB::Database
    @@db ||= DB.open MYSQL_URI
  end

  def self.close
    db.close unless @@db.nil?
  end
end
