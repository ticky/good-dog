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

def copy_window(window:, workspace:)
  puts "Copy window #{window} to #{workspace}..."

  GoodDog::Database.with_database write: true do |displays, workspaces, applications, stored_windows, windows|
    # first look up the window and stored_window
    source_window = windows.where(:Z_PK => window).first
    source_stored_window = stored_windows.where(:Z_PK => window).first

    # look up the application associated with that stored_window
    source_application = applications.where(:Z_PK => source_stored_window[:ZAPPLICATION]).first

    if source_application[:ZWORKSPACE] == workspace
      puts "Attempted to copy window \##{window} to a workspace it already exists in (\##{workspace})! Aborting."
      exit 1
    end

    # okay now let's grab the the target workspace
    target_workspace = workspaces.where(:Z_PK => workspace).first

    if target_workspace.nil?
      puts "Attempted to copy window \##{window} to a workspace which doesn't exist (\##{workspace})! Aborting."
      exit 1
    end

    # grab the source workspace so we can figure out which display this window is on
    source_workspace_displays = displays.where(:ZWORKSPACE => source_application[:ZWORKSPACE])

    # check the target workspace has an appropriate display to copy to
    source_display = which_of_these_displays source_workspace_displays, is_this_window_on: source_stored_window

    _, source_display_dimensions = GoodDog::Coordinates.parse source_display[:ZDISPLAYBOUNDS]
    target_workspace_displays = displays.where(:ZWORKSPACE => workspace).to_a.select do |display|
      _, display_dimensions = GoodDog::Coordinates.parse display[:ZDISPLAYBOUNDS]

      display_dimensions == source_display_dimensions
    end

    unless target_workspace_displays.any?
      puts "Attempted to copy window \##{window} to a workspace with no compatible displays. Aborting."
      exit 1
    end

    # TODO: This ambiguity will suck on triple monitor setups, need some workaround

    if target_workspace_displays.count > 1
      puts "Multiple displays in workspace \##{workspace} match. Aborting."
      exit 1
    end

    # let's find out if the application has an equivalent entry in the target workspace
    target_workspace_application = applications.where(
      :ZBUNDLEIDENTIFIER => source_application[:ZBUNDLEIDENTIFIER],
      :ZWORKSPACE => workspace
    ).first

    if target_workspace_application.nil?
      puts 'TODO: we need to create a new application entry for this workspace!'
    end

    puts source_window,
         source_stored_window,
         source_application,
         source_display,
         target_workspace,
         target_workspace_displays,
         target_workspace_application
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
  copy_window(window: opts[:window], workspace: opts[:to])
  exit
end

puts opts
