require 'json'

def parse_coordinates(bounds)
  # pretty sure this is, like, Obj-C array syntax?
  JSON.parse(
    bounds.gsub(
      /[\{\}]/,
      '{' => '[',
      '}' => ']'
    )
  )
end

def stringify_coordinates(array)
  JSON.generate(array).gsub(
    /,/,
    ', '
  ).gsub(
    /[\[\]]/,
    '[' => '{',
    ']' => '}'
  )
end
