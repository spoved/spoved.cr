require "open-api"
require "tablo"
require "./register/*"

module Spoved::Kemal
  register_spoved_defaults
end

def print_routes
  resources = Spoved::Kemal::SPOVED_ROUTES.map(&.last).uniq!.sort
  resources.each do |resource|
    puts resource

    data = Spoved::Kemal::SPOVED_ROUTES.select(&.last.==(resource))
    table = Tablo::Table.new(data, connectors: Tablo::CONNECTORS_SINGLE_DOUBLE) do |t|
      t.add_column("Path", &.[0])
      t.add_column("Route", &.[1])
    end

    table.shrinkwrap!
    puts table
    puts ""
  end
end
