#!/usr/bin/env ruby

require 'slop'
require './lib/coordinates'
require './lib/database'

def which_of_these_displays(displays, is_this_window_on:)
  window_position, window_dimensions = GoodDog::Coordinates.parse is_this_window_on[:ZFRAMESTRING]

  displays.find do |display|
    display_position, display_dimensions = GoodDog::Coordinates.parse display[:ZDISPLAYBOUNDS]

    window_position[0] >= display_position[0] &&
    window_position[1] >= display_position[1] &&
    window_position[0] < (display_position[0] + display_dimensions[0]) &&
    window_position[1] < (display_position[1] + display_dimensions[1])
  end
end

def list_windows
  GoodDog::Database.with_database do |displays, workspaces, applications, stored_windows, windows|
    puts "#{workspaces.count} workspaces with #{applications.count} application profiles found"

    workspaces.order(:ZNAME).each do |row|
      workspace_displays = displays.where(:ZWORKSPACE => row[:Z_PK])
      workspace_applications = applications.where(:ZWORKSPACE => row[:Z_PK])
      puts " • “#{row[:ZNAME]}” (Workspace \##{row[:Z_PK]})"

      puts "   Displays (#{workspace_displays.count}):"
      workspace_displays.each do |display|
        display_position, display_dimensions = GoodDog::Coordinates.parse display[:ZDISPLAYBOUNDS]

        puts "   • “#{display[:ZPRODUCTNAME]}”, #{display_dimensions.join '×'} at #{display_position} (Display \##{display[:Z_PK]})"
      end

      puts "   Applications (#{workspace_applications.count}):"
      workspace_applications.order(:ZNAME).each do |application|
        application_stored_windows = stored_windows.where(:ZAPPLICATION => application[:Z_PK])
        puts "   • “#{application[:ZNAME]}” (#{application_stored_windows.count} windows)"

        application_stored_windows.each do |stored_window|
          window = windows.where(:ZSTOREDWINDOW => stored_window[:Z_PK]).first
          window_position, window_dimensions = GoodDog::Coordinates.parse stored_window[:ZFRAMESTRING]

          title = "“#{window[:ZTITLE]}”"
          title = "/#{stored_window[:ZTITLEREGULAREXPRESSION]}/" if stored_window[:ZTITLEREGULAREXPRESSION]
          title = "Any window" if title == '/.*/'

          display_info = nil

          if workspace_displays.count > 1
            target_display = which_of_these_displays workspace_displays, is_this_window_on: stored_window

            if target_display
              display_info = ", shown on ”#{target_display[:ZPRODUCTNAME]}” (Display \##{target_display[:Z_PK]})"
            end
          end

          puts "     • #{title}, #{window_dimensions.join '×'} at #{window_position} (\##{stored_window[:Z_PK]})#{display_info}"
        end
      end
    end
  end
end

def copy_window(window:, display:)
  puts "Attempting to copy window \##{window} to display \##{display}..."

  GoodDog::Database.with_database write: true do |displays, workspaces, applications, stored_windows, windows|
    # first look up the window and stored_window
    source_window = windows.where(:Z_PK => window).first
    source_stored_window = stored_windows.where(:Z_PK => window).first

    # look up the application associated with that stored_window
    source_application = applications.where(:Z_PK => source_stored_window[:ZAPPLICATION]).first

    # grab the source workspace so we can figure out which display this window is on
    source_workspace_displays = displays.where(:ZWORKSPACE => source_application[:ZWORKSPACE])

    # check the target workspace has an appropriate display to copy to
    source_display = which_of_these_displays source_workspace_displays, is_this_window_on: source_stored_window
    source_display_offset, source_display_dimensions = GoodDog::Coordinates.parse source_display[:ZDISPLAYBOUNDS]

    target_display = displays.where(:Z_PK => display).first
    target_display_offset, target_display_dimensions = GoodDog::Coordinates.parse target_display[:ZDISPLAYBOUNDS]

    if target_display_dimensions != source_display_dimensions
      puts "Window \##{window} is on a #{source_display_dimensions.join '×'} display, it can't be copied to a #{target_display_dimensions.join '×'} display! Aborting."
      exit 1
    end

    if target_display[:ZWORKSPACE] == source_application[:ZWORKSPACE]
      puts "Window \##{window} is already on workspace #{target_display[:ZWORKSPACE]}! Aborting."
      exit 1
    end

    # let's find out if the application has an equivalent entry in the target workspace
    target_application = applications.where(
      :ZBUNDLEIDENTIFIER => source_application[:ZBUNDLEIDENTIFIER],
      :ZWORKSPACE => target_display[:ZWORKSPACE]
    ).first

    if target_application.nil?
      puts 'TODO: Copy source_application to new workspace'
    end

    puts 'TODO: Copy source_stored_window to new workspace'

    puts 'TODO: Copy source_window to new workspace'

    puts source_window,
         source_stored_window,
         source_application,
         source_display,
         target_display,
         target_application
  end
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
  opts.bool '--copy', 'Copy a window configuration to a new display'

  opts.integer '--window', '-w', 'Window ID to copy'
  opts.integer '--to', '-2', 'Display ID to copy specified `--window` to'

  opts.separator ""
  opts.separator "Other options:"

  opts.on '--help', 'Show usage' do
    puts opts
    exit
  end
end

if opts[:copy] && !opts[:window].nil? && !opts[:to].nil?
  copy_window(window: opts[:window], display: opts[:to])
  exit
end

puts opts
