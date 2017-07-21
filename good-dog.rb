#!/usr/bin/env ruby

require 'slop'
require './lib/coordinates'
require './lib/database'

def list_windows
  GoodDog::Database.with_database do |displays, workspaces, applications, stored_windows, windows|
    puts "#{workspaces.count} workspaces with #{applications.count} application profiles found"

    workspaces.order(:ZNAME).each do |row|
      workspace_displays = displays.where(:ZWORKSPACE => row[:Z_PK])
      workspace_applications = applications.where(:ZWORKSPACE => row[:Z_PK])
      puts " • “#{row[:ZNAME]}” (Workspace \##{row[:Z_PK]})"

      puts "   Displays (#{workspace_displays.count}):"
      parsed_displays = workspace_displays.map do |display|
        display_position, display_dimensions = parse_coordinates display[:ZDISPLAYBOUNDS]

        puts "   • “#{display[:ZPRODUCTNAME]}”, #{display_dimensions.join '×'} at #{display_position} (Display \##{display[:Z_PK]})"

        display_extents = [
          display_position[0] + display_dimensions[0],
          display_position[1] + display_dimensions[1],
        ]

        {
          display: display,
          parsed_position: display_position,
          parsed_dimensions: display_dimensions,
          parsed_extents: display_extents
        }
      end

      puts "   Applications (#{workspace_applications.count}):"
      workspace_applications.order(:ZNAME).each do |application|
        application_stored_windows = stored_windows.where(:ZAPPLICATION => application[:Z_PK])
        puts "   • “#{application[:ZNAME]}” (#{application_stored_windows.count} windows)"

        application_stored_windows.each do |stored_window|
          window = windows.where(:ZSTOREDWINDOW => stored_window[:Z_PK]).first
          window_position, window_dimensions = parse_coordinates stored_window[:ZFRAMESTRING]

          title = "“#{window[:ZTITLE]}”"
          title = "/#{stored_window[:ZTITLEREGULAREXPRESSION]}/" if stored_window[:ZTITLEREGULAREXPRESSION]
          title = "Any window" if title == '/.*/'

          display_info = nil

          if parsed_displays.count > 1
            parsed_displays.each do |display_data|
              if window_position[0] >= display_data[:parsed_position][0] && window_position[1] >= display_data[:parsed_position][1] && window_position[0] < display_data[:parsed_extents][0] && window_position[1] < display_data[:parsed_extents][1]
                display_info = ", shown on ”#{display_data[:display][:ZPRODUCTNAME]}” (Display \##{display_data[:display][:Z_PK]})"
                break
              end
            end
          end

          puts "     • #{title}, #{window_dimensions.join '×'} at #{window_position} (\##{stored_window[:Z_PK]})#{display_info}"
        end
      end
    end
  end
end

def copy_window(window:, configuration:)
  # TODO:
  # Check for args, accept window ID and workspace ID
  # Copy a config as proof of concept

  puts "Copy window #{window} to #{configuration}..."
end

opts = Slop.parse do |opts|
  opts.separator ""
  opts.separator "Listing options:"
  opts.on '--list', 'List configurations' do
    list_windows
    exit
  end

  opts.separator ""
  opts.separator "Copy options:"
  opts.bool '--copy', 'Copy a window configuration to a new workspace'

  opts.integer '--window', '-w', 'Window ID to copy'
  opts.integer '--to', '-2', 'Configuration ID to copy specified `--window` to'

  opts.separator ""
  opts.separator "Other options:"

  opts.on '--help', 'Show usage' do
    puts opts
    exit
  end
end

if opts[:copy] && !opts[:window].nil? && !opts[:to].nil?
  copy_window(window: opts[:window], configuration: opts[:to])
  exit
end

puts opts
