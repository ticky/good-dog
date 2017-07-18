require 'sys/proctable'
include Sys

def warn_if_running
  ProcTable.ps do |proc|
    if proc.name == 'Stay'
      puts "WARNING: Stay is currently running (process #{proc.pid}). Changes to the database may not be kept!"
      break
    end
  end
end
