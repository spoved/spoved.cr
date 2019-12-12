require "json"
require "uuid"
require "uuid/json"

require "db"
require "mysql"
require "../model"

class Spoved::DB::Model::MySQL < Spoved::DB::Model
  spoved_logger

  alias DataHash = Hash(String, Array(JSON::Any) | Bool | Float64 | Hash(String, JSON::Any) | Int64 | String | Nil)

  MYSQL_DB_NAME = ENV["CRYSTAL_ENV"]? ? "#{ENV["MYSQL_DB_NAME"]}_#{ENV["CRYSTAL_ENV"]?}" : "#{ENV["MYSQL_DB_NAME"]}"

  MYSQL_URI = URI.new(
    scheme: "mysql",
    host: ENV["MYSQL_HOST"]? || "localhost",
    port: (ENV["MYSQL_PORT"]? || 3306).to_i,
    path: "\\" + MYSQL_DB_NAME,
    # query: "schema=#{MYSQL_DB_NAME}",
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || ""
  )

  MYSQL_RO_URI = URI.new(
    scheme: "mysql",
    host: ENV["MYSQL_RO_HOST"]? || ENV["MYSQL_HOST"]? || "localhost",
    port: (ENV["MYSQL_RO_PORT"]? || ENV["MYSQL_PORT"]? || 3306).to_i,
    path: "\\" + MYSQL_DB_NAME,
    # query: "schema=#{MYSQL_DB_NAME}",
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || ""
  )

  @@db : ::DB::Database?
  @@db_ro : ::DB::Database?

  def self.db : ::DB::Database
    @@db ||= ::DB.open MYSQL_URI
  end

  def self.db_ro : ::DB::Database
    @@db_ro ||= ::DB.open MYSQL_RO_URI
  end

  def self.close
    db.close unless @@db.nil?
  end

  def self.db_name
    MYSQL_DB_NAME
  end

  def self.db_uri
    MYSQL_URI
  end
end
