module GoodDog
  class SubprocessError < StandardError; end

  module ProcessStatus
    # Returns an array of hashes whose keys are the columns in the `ps` output.
    module_function def aux
      processes = `ps aux 2>&1`
      if $?.exitstatus != 0
        raise SubprocessError, "Unable to run `ps`! Output was: #{processes}"
      end

      data = processes.each_line.map(&:chomp)
      headers = data[0].split(" ")
      data = data[1..-1]

      data.map do |line|
        # Limit the split to headers.length because commands are likely to have spaces.
        # It'd sure be nice if `ps` had \t-delimited output, huh?
        headers.zip(line.split(" ", headers.length)).to_h
      end
    end

    module_function def command_running?(name, fuzzy: true)
      aux.any? do |process|
        if fuzzy
          process["COMMAND"].match? name
        else
          process["COMMAND"] == name
        end
      end
    end
  end
end
