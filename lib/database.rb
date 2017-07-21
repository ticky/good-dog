require 'sequel'
require_relative 'ps'

module GoodDog
  class DatabaseError < StandardError; end
  class DatabaseMissingError < DatabaseError; end

  module Database
    module_function def with_database(write: false, file: File.expand_path('~/Library/Application Support/Stay/Stored Windows.sqlite'))
      unless File.exist? file
        raise DatabaseMissingError, 'Couldn\'t find a Stay database!'
      end

      if write
        if GoodDog::PS.command_running? 'Stay'
          $stderr.puts 'WARNING: Stay is currently running. Changes to the database may not be kept!'
        end
      end

      Sequel.sqlite file do |db|
        displays = db.from(:ZDISPLAY)
        workspaces = db.from(:ZWORKSPACE)
        applications = db.from(:ZAPPLICATION)
        stored_windows = db.from(:ZSTOREDWINDOW)
        windows = db.from(:ZWINDOW)

        yield displays, workspaces, applications, stored_windows, windows
      end
    end
  end
end