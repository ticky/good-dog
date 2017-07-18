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
  stored_windows = db.from(:ZSTOREDWINDOW)
  windows = db.from(:ZWINDOW)

  puts "#{workspaces.count} workspaces with #{applications.count} application profiles found"

  workspaces.order(:ZNAME).each do |row|
    workspace_displays = displays.where(:ZWORKSPACE => row[:Z_PK])
    workspace_applications = applications.where(:ZWORKSPACE => row[:Z_PK])
    puts " • “#{row[:ZNAME]}” (Workspace \##{row[:Z_PK]})"

    puts "   Displays (#{workspace_displays.count}):"
    workspace_displays.each do |display|
      display_position, display_dimensions = parse_bounds display[:ZDISPLAYBOUNDS]

      puts "   • “#{display[:ZPRODUCTNAME]}”, #{display_dimensions.join '×'} at #{display_position} (Display \##{display[:Z_PK]})"
    end

    puts "   Applications (#{workspace_applications.count}):"
    workspace_applications.order(:ZNAME).each do |application|
      application_stored_windows = stored_windows.where(:ZAPPLICATION => application[:Z_PK])
      puts "   • “#{application[:ZNAME]}” (#{application_stored_windows.count} windows)"

      application_stored_windows.each do |stored_window|
        window = windows.where(:ZSTOREDWINDOW => stored_window[:Z_PK]).first
        window_position, window_dimensions = parse_bounds stored_window[:ZFRAMESTRING]

        title = "“#{window[:ZTITLE]}”"

        title = "/#{stored_window[:ZTITLEREGULAREXPRESSION]}/" if stored_window[:ZTITLEREGULAREXPRESSION]

        title = "Any window" if title == '/.*/'

        puts "     • #{title}, #{window_dimensions.join '×'} at #{window_position}"
      end
    end
  end
end
