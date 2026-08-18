var API_URL = "https://api.svgl.app"

function parseSvgl(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (e) {
    return { fetchedAt: 0, items: [] }
  }
  if (Array.isArray(data)) return { fetchedAt: 0, items: data }
  if (data && Array.isArray(data.items))
    return { fetchedAt: Number(data.fetchedAt) || 0, items: data.items }
  return { fetchedAt: 0, items: [] }
}

function categoryList(value) {
  if (Array.isArray(value)) {
    var out = []
    for (var i = 0; i < value.length; i++) {
      var name = String(value[i] || "").trim()
      if (name && out.indexOf(name) === -1) out.push(name)
    }
    return out
  }
  var single = String(value || "").trim()
  return single ? [single] : []
}

function normalizeLogos(svgs) {
  var values = Array.isArray(svgs) ? svgs : []
  var out = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item || typeof item !== "object") continue
    var title = String(item.title || "").trim()
    if (!title || !item.route) continue
    out.push({
      id: Number(item.id) || out.length,
      title: title,
      categories: categoryList(item.category),
      route: item.route,
      url: String(item.url || ""),
      brandUrl: String(item.brandUrl || "")
    })
  }
  return out
}

function categoriesOf(logos) {
  var counts = {}
  var order = []
  var total = 0
  for (var i = 0; i < logos.length; i++) {
    total++
    var cats = logos[i].categories
    if (cats.length === 0) cats = ["Uncategorized"]
    for (var j = 0; j < cats.length; j++) {
      if (!counts[cats[j]]) {
        counts[cats[j]] = 0
        order.push(cats[j])
      }
      counts[cats[j]]++
    }
  }
  order.sort(function(a, b) {
    var diff = counts[b] - counts[a]
    if (diff !== 0) return diff
    return a.toLowerCase() < b.toLowerCase() ? -1 : 1
  })
  var out = [{ name: "All", total: total }]
  for (i = 0; i < order.length; i++) out.push({ name: order[i], total: counts[order[i]] })
  return out
}

function normalizedQuery(query) {
  return String(query || "").trim().toLowerCase()
}

function matchesCategory(logo, category) {
  if (!category || category === "All") return true
  var wanted = category.toLowerCase()
  var cats = logo.categories
  if (cats.length === 0) return wanted === "uncategorized"
  for (var i = 0; i < cats.length; i++) {
    if (cats[i].toLowerCase() === wanted) return true
  }
  return false
}

function filterLogos(logos, query, category, limit) {
  var values = Array.isArray(logos) ? logos : []
  var needle = normalizedQuery(query)
  var max = limit === undefined || limit === null ? 800 : Number(limit)
  if (isNaN(max)) max = 800
  max = Math.max(0, max)
  if (max === 0) return []

  var out = []
  for (var i = 0; i < values.length; i++) {
    var logo = values[i]
    if (!logo || !logo.title) continue
    if (!matchesCategory(logo, category)) continue
    if (needle && logo.title.toLowerCase().indexOf(needle) === -1) continue
    out.push(logo)
    if (out.length >= max) break
  }
  return out
}

function routeUrl(route, preferDark) {
  if (typeof route === "string") return route
  if (route && typeof route === "object") {
    if (preferDark && route.dark) return String(route.dark)
    return String(route.light || route.dark || "")
  }
  return ""
}

function slugFor(url, fallbackId) {
  var path = String(url || "")
  var query = path.indexOf("?")
  if (query !== -1) path = path.slice(0, query)
  var slash = path.lastIndexOf("/")
  var name = slash !== -1 ? path.slice(slash + 1) : path
  name = name.replace(/[^A-Za-z0-9._-]/g, "-").replace(/^\.+/, "")
  if (!name) name = "logo-" + String(fallbackId === undefined ? 0 : fallbackId) + ".svg"
  return name
}

function isDark(color) {
  if (!color) return true
  var luminance = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
  return luminance < 0.45
}

var FORMATS = ["svg", "shadcn", "jsx", "tsx"]

function shadcnSlug(title) {
  return String(title || "").toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "")
}

function shadcnCommand(title) {
  return "npx shadcn@latest add @svgl/" + shadcnSlug(title)
}

function componentName(title) {
  var words = String(title || "").split(/[^A-Za-z0-9]+/)
  var out = ""
  for (var i = 0; i < words.length; i++) {
    if (words[i]) out += words[i].charAt(0).toUpperCase() + words[i].slice(1)
  }
  if (!out) return "Logo"
  if (out.charAt(0) >= "0" && out.charAt(0) <= "9") return "Logo" + out
  return out
}

var REACT_ATTRS = {
  "class": "className",
  "clip-rule": "clipRule",
  "clip-path": "clipPath",
  "fill-rule": "fillRule",
  "stroke-width": "strokeWidth",
  "stroke-linecap": "strokeLinecap",
  "stroke-linejoin": "strokeLinejoin",
  "stroke-dasharray": "strokeDasharray",
  "stroke-dashoffset": "strokeDashoffset",
  "stroke-miterlimit": "strokeMiterlimit",
  "xmlns:xlink": "xmlnsXlink",
  "text-anchor": "textAnchor",
  "xml:space": "xmlSpace",
  "stop-color": "stopColor",
  "stop-opacity": "stopOpacity",
  "color-interpolation-filters": "colorInterpolationFilters",
  "xlink:href": "xlinkHref",
  "flood-opacity": "floodOpacity",
  "flood-color": "floodColor",
  "fill-opacity": "fillOpacity"
}

function styleToObject(styleString) {
  var parts = String(styleString || "").split(";")
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var colon = parts[i].indexOf(":")
    if (colon === -1) continue
    var prop = parts[i].slice(0, colon).replace(/^\s+|\s+$/g, "")
    var value = parts[i].slice(colon + 1).replace(/^\s+|\s+$/g, "")
    if (!prop || !value) continue
    var camel = prop.replace(/-([a-z])/g, function(m, g) { return g.toUpperCase() })
    out.push('"' + camel + '": "' + value + '"')
  }
  return "{" + out.join(", ") + "}"
}

function cleanSvgForReact(svgCode) {
  var svg = String(svgCode || "")
  svg = svg.replace(/<\?xml[^>]*\?>/g, "")
  svg = svg.replace(/<!DOCTYPE[^>]*>/gi, "")
  svg = svg.replace(/<!--[\s\S]*?-->/g, "")
  svg = svg.replace(/<metadata[\s\S]*?<\/metadata>/g, "")
  svg = svg.replace(/<sodipodi:namedview[\s\S]*?<\/sodipodi:namedview>/gi, "")
  svg = svg.replace(/<style([^>]*)>([\s\S]*?)<\/style>/g, function(m, attrs, content) {
    var cleaned = content.replace(/<!\[CDATA\[/g, "").replace(/\]\]>/g, "")
    return "<style" + attrs + ">{" + JSON.stringify(cleaned) + "}</style>"
  })
  svg = svg.replace(/<!\[CDATA\[/g, "")
  svg = svg.replace(/\]\]>/g, "")
  svg = svg.replace(/\s+(osb|dc|cc|rdf|svg|sodipodi|inkscape):[A-Za-z-]+="[^"]*"/g, "")
  svg = svg.replace(/\s+xmlns:(?!xlink)[A-Za-z-]+="[^"]*"/g, "")
  return svg
}

function reactifySvg(svgCode) {
  var svg = cleanSvgForReact(svgCode)
  svg = svg.replace(/style="([^"]*)"/g, function(m, s) { return "style={" + styleToObject(s) + "}" })
  svg = svg.replace("<svg", "<svg {...props}")
  for (var key in REACT_ATTRS) svg = svg.split(key + '="').join(REACT_ATTRS[key] + '="')
  return svg
}

function toReactComponent(svgCode, title, typescript) {
  var name = componentName(title)
  var body = reactifySvg(svgCode)
  if (typescript) {
    return "import type { SVGProps } from \"react\";\n\n"
      + "const " + name + " = (props: SVGProps<SVGSVGElement>) => (\n  " + body + "\n);\n\n"
      + "export { " + name + " };\n"
  }
  return "const " + name + " = (props) => (\n  " + body + "\n);\n\n"
    + "export { " + name + " };\n"
}

if (typeof module !== "undefined") {
  module.exports = {
    API_URL: API_URL,
    parseSvgl: parseSvgl,
    normalizeLogos: normalizeLogos,
    categoriesOf: categoriesOf,
    filterLogos: filterLogos,
    routeUrl: routeUrl,
    slugFor: slugFor,
    isDark: isDark,
    FORMATS: FORMATS,
    shadcnCommand: shadcnCommand,
    componentName: componentName,
    reactifySvg: reactifySvg,
    toReactComponent: toReactComponent
  }
}
