#!/usr/bin/env ruby

require 'sequel'
require 'json'

STAY_DATABASE_PATH = File.expand_path '~/Library/Application Support/Stay/Stored Windows.sqlite'

unless File.exist? STAY_DATABASE_PATH
  puts "Couldn't find a Stay database!"
  exit 1
end

def parse_bounds(bounds)
  # pretty sure this is, like, Obj-C array syntax?
  JSON.parse(
    bounds.gsub(
      /[\{\}]/,
      '{' => '[',
      '}' => ']'
    )
  )
end

Sequel.sqlite STAY_DATABASE_PATH do |db|
  displays = db.from(:ZDISPLAY)
  workspaces = db.from(:ZWORKSPACE)
  applications = db.from(:ZAPPLICATION)
  windows = db.from(:ZWINDOW)
  stored_windows = db.from(:ZSTOREDWINDOW)

  puts "#{workspaces.count} workspaces with #{applications.count} application profiles found"

  workspaces.order(:ZNAME).each do |row|
    workspace_displays = displays.where(:ZWORKSPACE => row[:Z_PK])
    puts " • “#{row[:ZNAME]}” (Workspace \##{row[:Z_PK]})"

    workspace_displays.each do |display|
      position, dimensions = parse_bounds display[:ZDISPLAYBOUNDS]

      puts "   • “#{display[:ZPRODUCTNAME]}”, #{dimensions.join '×'} at #{position} (Display \##{display[:Z_PK]})"
    end
  end
end
