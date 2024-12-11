#let cache = state("code.insert.cache", (:))

#let extract_info(pair) = {
  let first_match = pair.at(0)
  let second_match = pair.at(1)
  let label = first_match.at("captures").at(0)
  let content_start = first_match.at("end")
  let content_end = second_match.at("start")
  return (label, content_start, content_end)
}

#let insert(file, section, lang: "c") = {
  let c = context cache.get()
  let entry = c.at(file, default: false)
  if entry == false {
    let new_entry = (:)
    let content = read(file)

    let matches = content.matches(regex("//=+ Section(?: End)?: (?<label>[a-zA-Z_\-0-9]+) =+//"))
    let match_pairs = matches.chunks(2)
    let info = match_pairs.map(extract_info)
    for f in info {
      let label = f.at(0)
      // FIXME: String.trim the slice instead of +/- 1
      let section = content.slice(f.at(1) + 1, f.at(2) - 1) // +/- 1 to skip newlines
      new_entry.insert(label, section)
    }

    cache.update(d => d.insert(file, new_entry))
    entry = new_entry
  }

  return raw(entry.at(section), lang: lang)
}

