# Rewrites a YASB stylesheet onto Stillwater in one pass.
# awk -v version=X -f rewrite.awk palette.json vars.map hex.map styles.css
# POSIX awk only (mawk, BSD awk): no interval braces, no gawk functions.

function hexval(s,    i, n) {
  n = 0
  s = tolower(s)
  for (i = 1; i <= length(s); i++) n = n * 16 + index("0123456789abcdef", substr(s, i, 1)) - 1
  return n
}

function skip_hex(h) {
  return h == "0078d4" || h == "199143" || h == "ff583b" || h == "1db954" || h == "ffffff" || h == "000000"
}

function map_hex(h,    role) {
  h = tolower(h)
  if (length(h) == 3) h = substr(h, 1, 1) substr(h, 1, 1) substr(h, 2, 1) substr(h, 2, 1) substr(h, 3, 1) substr(h, 3, 1)
  if (skip_hex(h)) return ""
  role = hexrole[h]
  if (role == "") return ""
  return pal[role]
}

function rgb_of(h) {
  return hexval(substr(h, 1, 2)) ", " hexval(substr(h, 3, 2)) ", " hexval(substr(h, 5, 2))
}

function format_value(old, h,    alpha, n) {
  h = tolower(h)
  if (substr(old, 1, 5) == "rgba(") {
    n = split(old, parts, ",")
    alpha = parts[n]
    sub(/\)$/, "", alpha)
    return "rgba(" rgb_of(h) "," alpha ")"
  }
  if (substr(old, 1, 4) == "rgb(") return "rgb(" rgb_of(h) ")"
  if (old ~ /^[0-9]+,/) return rgb_of(h)
  return "#" h
}

function rewrite_colors(line,    out, m, inner, n, h, mapped, rest) {
  out = ""
  while (match(line, RGB)) {
    m = substr(line, RSTART, RLENGTH)
    out = out substr(line, 1, RSTART - 1)
    line = substr(line, RSTART + RLENGTH)
    inner = m
    sub(/^rgba?\(/, "", inner)
    sub(/\)$/, "", inner)
    n = split(inner, nums, ",")
    gsub(/[ \t]/, "", nums[1]); gsub(/[ \t]/, "", nums[2]); gsub(/[ \t]/, "", nums[3])
    rest = ""
    if (n > 3) {
      rest = inner
      sub(/^[^,]*,[^,]*,[^,]*/, "", rest)
    }
    h = sprintf("%02x%02x%02x", nums[1], nums[2], nums[3])
    mapped = map_hex(h)
    if (mapped == "") out = out m
    else if (substr(m, 1, 4) == "rgba") out = out "rgba(" rgb_of(mapped) rest ")"
    else out = out "rgb(" rgb_of(mapped) ")"
  }
  line = out line
  out = ""
  while (match(line, HEX)) {
    m = substr(line, RSTART, RLENGTH)
    out = out substr(line, 1, RSTART - 1)
    line = substr(line, RSTART + RLENGTH)
    mapped = map_hex(substr(m, 2))
    out = out (mapped == "" ? m : "#" mapped)
  }
  return out line
}

function rewrite_line(line,    indent, name, value, rest, key, role, h, p) {
  if (line !~ VAR) return rewrite_colors(line)
  match(line, /^[ \t]*/)
  indent = substr(line, 1, RLENGTH)
  rest = substr(line, RLENGTH + 3)
  match(rest, /^[A-Za-z0-9-]+/)
  name = substr(rest, 1, RLENGTH)
  rest = substr(rest, RLENGTH + 1)
  sub(/^[ \t]*:[ \t]*/, "", rest)
  p = index(rest, ";")
  value = substr(rest, 1, p - 1)
  rest = substr(rest, p + 1)
  gsub(/^[ \t]+|[ \t]+$/, "", value)
  if (substr(value, 1, 4) == "var(" || value == "transparent" || value == "none") return line
  key = tolower(name)
  role = varrole[key]
  if (role == "" && key ~ /-rgb$/) role = varrole[substr(key, 1, length(key) - 4)]
  if (role != "") {
    h = pal[role]
    if (h != "") return indent "--" name ": " format_value(value, h) ";" rest
  }
  return rewrite_colors(line)
}

BEGIN {
  H = "[0-9A-Fa-f]"
  HEX = "#(" H H H H H H "|" H H H ")"
  S = "[ \t]*"
  RGB = "rgba?\\(" S "[0-9]+" S "," S "[0-9]+" S "," S "[0-9]+" S "(,[^)]*)?\\)"
  VAR = "^" S "--[A-Za-z0-9-]+" S ":" S "[^;]+;"
  PALKEY = "^" S "\"[A-Za-z]+\"" S ":" S "\"#" H H H H H H "\""
}

FNR == 1 { file++ }

# Windows checkouts can carry CRLF in the maps and the stylesheet.
{ sub(/\r$/, "") }

file == 1 {
  if (match($0, PALKEY)) {
    split(substr($0, RSTART, RLENGTH), kv, "\"")
    if (!(kv[2] in pal)) pal[kv[2]] = substr(kv[4], 2)
  }
  next
}

file == 2 {
  if (NF == 2 && !($1 in varrole)) varrole[$1] = $2
  next
}

file == 3 {
  if (NF == 2) {
    k = tolower($1)
    if (!(k in hexrole)) hexrole[k] = $2
  }
  next
}

{
  line = $0
  if (index(line, "@version")) {
    if (match(line, "@version" S "[0-9][0-9.]*[0-9]")) line = substr(line, 1, RSTART - 1) "@version " version substr(line, RSTART + RLENGTH)
    stamped = 1
  }
  if (depth == 0 && !stamped && index(line, ":root")) {
    print "/* @version " version " */"
    stamped = 1
  }
  opens = gsub(/\{/, "{", line)
  closes = gsub(/\}/, "}", line)
  print rewrite_line(line)
  depth += opens - closes
  if (depth < 0) depth = 0
}
