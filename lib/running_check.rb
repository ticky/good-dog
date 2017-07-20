require_relative "ps"

def warn_if_running
  if GoodDog::PS.command_running? "Stay"
    puts "WARNING: Stay is currently running. Changes to the database may not be kept!"
  end
end
