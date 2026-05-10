-- gwark Lua filter test: wrap every Str in Emph and tag the doc with
-- a metadata field. Exercises Inline construction, Pandoc walk, and
-- Meta mutation.
function Str (el)
  return pandoc.Emph { el }
end

function Pandoc (doc)
  doc.meta["wrap-emph"] = pandoc.MetaBool(true)
  return doc
end
