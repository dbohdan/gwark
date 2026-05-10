-- gwark Lua filter test: uppercase every Str element.
function Str (el)
  return pandoc.Str(string.upper(el.text))
end
