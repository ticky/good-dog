require 'json'

module GoodDog
  module Coordinates
    module_function def parse(bounds)
      # pretty sure this is, like, Obj-C array syntax?
      JSON.parse(
        bounds.gsub(
          /[\{\}]/,
          '{' => '[',
          '}' => ']'
        )
      )
    end

    module_function def stringify(array)
      JSON.generate(array).gsub(
        /,/,
        ', '
      ).gsub(
        /[\[\]]/,
        '[' => '{',
        ']' => '}'
      )
    end
  end
end
