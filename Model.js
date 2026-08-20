var SVGL_API_URL = "https://api.svgl.app"
var SVGL_SVG_URL = "https://api.svgl.app/svg/"
var SVGL_WEBSITE = "https://svgl.app/"
var DASHBOARD_CDN = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/"
var DASHBOARD_SEARCH_URL = "https://dashboardicons.com/api/icons/search"
var SIMPLE_ICONS_CDN = "https://cdn.simpleicons.org/"
var DASHBOARD_WEBSITE = "https://dashboardicons.com/"

var TYPES = ["svg", "png", "webp"]

var ACTIONS = {
  "svg":     { label: "SVG",      type: "svg" },
  "svgUrl":  { label: "SVG URL",  type: "svg" },
  "jsx":     { label: "JSX",      type: "svg" },
  "tsx":     { label: "TSX",      type: "svg" },
  "shadcn":  { label: "shadcn",   type: "svg" },
  "png":     { label: "PNG",      type: "png" },
  "pngUrl":  { label: "PNG URL",  type: "png" },
  "webp":    { label: "WebP",     type: "webp" },
  "webpUrl": { label: "WebP URL", type: "webp" }
}

function providerDefs() {
  return [
    {
      id: "dashboard",
      name: "dashboard icons",
      defaultEnabled: true,
      catalogUrl: DASHBOARD_SEARCH_URL,
      cacheFile: "dashboard.json",
      actions: ["svg", "svgUrl", "jsx", "tsx", "png", "pngUrl", "webp", "webpUrl"],
      website: DASHBOARD_WEBSITE
    },
    {
      id: "svgl",
      name: "svgl",
      defaultEnabled: true,
      catalogUrl: SVGL_API_URL,
      cacheFile: "svgl.json",
      actions: ["svg", "svgUrl", "jsx", "tsx", "shadcn"],
      website: SVGL_WEBSITE
    }
  ]
}

function parseConfig(raw) {
  var enabled = null
  var filter = null
  var touched = null
  try {
    var data = JSON.parse(String(raw || ""))
    if (data && Array.isArray(data.providers)) enabled = data.providers
    if (data && typeof data.filter === "string") filter = data.filter
    if (data && Array.isArray(data.touched)) touched = data.touched
  } catch (e) {}
  var defs = providerDefs()
  var all = []
  for (var i = 0; i < defs.length; i++) all.push(defs[i].id)
  var defaults = []
  for (i = 0; i < defs.length; i++) {
    if (defs[i].defaultEnabled) defaults.push(defs[i].id)
  }
  if (defaults.length === 0) defaults = all.slice()
  if (!enabled) {
    return { enabledIds: defaults.slice(), touched: defaults.slice(), filter: normalizeFilter(filter), fresh: true }
  }
  var out = []
  for (i = 0; i < defs.length; i++) {
    if (enabled.indexOf(defs[i].id) !== -1) out.push(defs[i].id)
  }
  var effTouched = touched ? touched.slice() : enabled.slice()
  return { enabledIds: out, touched: effTouched, filter: normalizeFilter(filter), fresh: false }
}

function normalizeFilter(filter) {
  if (!filter || String(filter).toLowerCase() === "all") return "all"
  var defs = providerDefs()
  for (var i = 0; i < defs.length; i++) {
    if (defs[i].id === filter) return defs[i].id
  }
  return "all"
}

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

function parseDashboard(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (e) {
    return { fetchedAt: 0, items: [] }
  }
  if (Array.isArray(data)) return { fetchedAt: 0, items: data }
  if (data && typeof data === "object" && Array.isArray(data.items))
    return { fetchedAt: Number(data.fetchedAt) || 0, items: data.items }
  if (data && typeof data === "object") {
    var items = []
    for (var key in data) {
      if (!data.hasOwnProperty(key)) continue
      var entry = data[key]
      if (entry && typeof entry === "object") {
        entry.id = key
        items.push(entry)
      }
    }
    return { fetchedAt: 0, items: items }
  }
  return { fetchedAt: 0, items: [] }
}

function parseProvider(providerId, raw) {
  if (providerId === "dashboard") return parseDashboard(raw)
  return parseSvgl(raw)
}

function normalizeCategory(name) {
  return String(name || "").trim().toLowerCase().replace(/-/g, " ")
}

var BRAND_NAMES = {
  github: "GitHub", gitlab: "GitLab", git: "Git", npm: "NPM", pnpm: "pnpm", yarn: "Yarn",
  nodejs: "Node.js", node: "Node.js", nextjs: "Next.js", nuxt: "Nuxt", vue: "Vue", react: "React",
  typescript: "TypeScript", javascript: "JavaScript", mysql: "MySQL", postgresql: "PostgreSQL",
  postgres: "PostgreSQL", mongodb: "MongoDB", redis: "Redis", nginx: "Nginx", apache: "Apache",
  docker: "Docker", kubernetes: "Kubernetes", terraform: "Terraform", ansible: "Ansible",
  jenkins: "Jenkins", grafana: "Grafana", prometheus: "Prometheus", linux: "Linux", python: "Python",
  golang: "Go", go: "Go", rust: "Rust", kotlin: "Kotlin", swift: "Swift", deno: "Deno", bun: "Bun",
  vite: "Vite", webpack: "Webpack", babel: "Babel", esbuild: "esbuild", biome: "Biome",
  vercel: "Vercel", netlify: "Netlify", cloudflare: "Cloudflare", vscode: "VS Code",
  vscodium: "VSCodium", figma: "Figma", notion: "Notion", slack: "Slack", discord: "Discord",
  telegram: "Telegram", whatsapp: "WhatsApp", linkedin: "LinkedIn", youtube: "YouTube",
  spotify: "Spotify", gmail: "Gmail", google: "Google", microsoft: "Microsoft", apple: "Apple",
  amazon: "Amazon", aws: "AWS", azure: "Azure", gcp: "GCP", heroku: "Heroku",
  digitalocean: "DigitalOcean", openai: "OpenAI", anthropic: "Anthropic", openvpn: "OpenVPN",
  wireguard: "WireGuard", traefik: "Traefik", vitest: "Vitest", storybook: "Storybook",
  nx: "Nx", pypi: "PyPI", dotenv: "dotenv", dotenvx: "dotenvx", shadcn: "shadcn",
  n8n: "n8n", "pi-hole": "Pi-hole", "xcp-ng": "XCP-ng", "node-red": "Node-RED",
  "open-webui": "Open WebUI", adguard: "AdGuard"
}

function titleWord(word) {
  if (word.length <= 1) return word.toUpperCase()
  if (/^[A-Z0-9]+$/.test(word) && !/^[0-9]+$/.test(word)) return word
  if (/[a-z]/.test(word) && /[A-Z]/.test(word.slice(1))) return word
  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
}

function titleCase(name) {
  var s = String(name || "").trim()
  if (!s) return s
  var lower = s.toLowerCase()
  if (BRAND_NAMES[lower]) return BRAND_NAMES[lower]
  s = s.replace(/-/g, " ")
  lower = s.toLowerCase()
  if (BRAND_NAMES[lower]) return BRAND_NAMES[lower]
  var out = ""
  var i = 0
  var len = s.length
  while (i < len) {
    var c = s.charAt(i)
    if (/[A-Za-z0-9]/.test(c)) {
      var j = i
      while (j < len && /[A-Za-z0-9]/.test(s.charAt(j))) j++
      out += titleWord(s.slice(i, j))
      i = j
    } else {
      out += c
      i++
    }
  }
  return out
}

function categoryList(value) {
  if (Array.isArray(value)) {
    var out = []
    for (var i = 0; i < value.length; i++) {
      var name = normalizeCategory(value[i])
      if (name && out.indexOf(name) === -1) out.push(name)
    }
    return out
  }
  var single = normalizeCategory(value)
  return single ? [single] : []
}

function normalizeLogos(svgs, providerId) {
  var values = Array.isArray(svgs) ? svgs : []
  var out = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item || typeof item !== "object") continue
    var title = titleCase(item.title)
    if (!title || !item.route) continue
    out.push({
      provider: providerId,
      id: Number(item.id) || out.length,
      title: title,
      search: title,
      categories: categoryList(item.category),
      route: item.route,
      url: String(item.url || ""),
      brandUrl: String(item.brandUrl || "")
    })
  }
  return out
}

function dashboardFormats(item) {
  if (item.source === "simpleicons") return ["svg"]
  if (item.source === "selfhst" || item.source === "lobehub") {
    var formats = item.external && Array.isArray(item.external.formats) ? item.external.formats : []
    if (formats.length === 0) formats = ["svg", "png", "webp"]
    return formats
  }
  return String(item.data && item.data.base) === "png" ? ["png", "webp"] : ["svg", "png", "webp"]
}

function normalizeDashboardLogos(entries) {
  var values = Array.isArray(entries) ? entries : []
  var out = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item || typeof item !== "object") continue
    var slug = String(item.slug || item.id || "").trim()
    if (!slug) continue
    var data = item.data || {}
    var aliases = Array.isArray(data.aliases) ? data.aliases.map(String) : []
    var clean = []
    for (var a = 0; a < aliases.length; a++) {
      var alias = aliases[a].trim()
      if (alias) clean.push(alias)
    }
    var title = titleCase(String(item.name || "").trim() || (clean.length > 0 ? clean[0] : slug))
    var source = String(item.source || "native").toLowerCase()
    var formats = dashboardFormats(item)
    out.push({
      provider: "dashboard",
      source: source,
      id: slug,
      slug: slug,
      title: title,
      search: (title + " " + slug + " " + clean.join(" ") + " " + source).trim(),
      categories: categoryList(data.categories),
      formats: formats,
      hasSvg: formats.indexOf("svg") !== -1,
      templates: item.external && item.external.url_templates && typeof item.external.url_templates === "object"
        ? item.external.url_templates : null,
      brand: item.external && typeof item.external.brand_color === "string" ? item.external.brand_color : "",
      url: DASHBOARD_WEBSITE,
      brandUrl: ""
    })
  }
  return out
}

function normalizeFor(providerId, items) {
  if (providerId === "dashboard") return normalizeDashboardLogos(items)
  return normalizeLogos(items, providerId)
}

function categoriesOf(logos) {
  var counts = {}
  var order = []
  var total = 0
  for (var i = 0; i < logos.length; i++) {
    total++
    var cats = logos[i].categories
    if (cats.length === 0) cats = ["uncategorized"]
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
  var out = [{ name: "all", total: total }]
  for (i = 0; i < order.length; i++) out.push({ name: order[i], total: counts[order[i]] })
  return out
}

function normalizedQuery(query) {
  return String(query || "").trim().toLowerCase()
}

function matchesCategory(logo, category) {
  if (!category) return true
  var wanted = String(category).toLowerCase()
  if (wanted === "all") return true
  var cats = logo.categories
  if (cats.length === 0) return wanted === "uncategorized"
  for (var i = 0; i < cats.length; i++) {
    if (cats[i].toLowerCase() === wanted) return true
  }
  return false
}

function filterLogos(logos, query, category, provider, limit) {
  var values = Array.isArray(logos) ? logos : []
  var needle = normalizedQuery(query)
  var max = limit === undefined || limit === null ? 10000 : Number(limit)
  if (isNaN(max)) max = 10000
  max = Math.max(0, max)
  if (max === 0) return []

  var out = []
  for (var i = 0; i < values.length; i++) {
    var logo = values[i]
    if (!logo || !logo.title) continue
    if (!matchesCategory(logo, category)) continue
    if (provider && String(provider).toLowerCase() !== "all" && logo.provider !== provider) continue
    if (needle && (logo.search || logo.title).toLowerCase().indexOf(needle) === -1) continue
    out.push(logo)
    if (out.length >= max) break
  }
  return out
}

function urlHost(url) {
  var u = String(url || "")
  var m = /^https?:\/\//i.exec(u)
  if (!m) return ""
  var rest = u.slice(m[0].length)
  var cut = rest.search(/[\/?#]/)
  if (cut !== -1) rest = rest.slice(0, cut)
  var at = rest.lastIndexOf("@")
  if (at !== -1) rest = rest.slice(at + 1)
  if (rest.charAt(0) === "[") {
    var end = rest.indexOf("]")
    if (end !== -1) {
      var after = rest.slice(end + 1)
      if (after !== "" && after.charAt(0) !== ":") return ""
      var inner = rest.slice(1, end)
      var zone = inner.indexOf("%")
      if (zone !== -1) inner = inner.slice(0, zone)
      return inner.toLowerCase()
    }
    return ""
  }
  var port = rest.lastIndexOf(":")
  if (port !== -1) rest = rest.slice(0, port)
  if (rest.indexOf(":") !== -1) return ""
  rest = rest.replace(/\.+$/, "")
  return rest.toLowerCase()
}

function isNumericIpLike(host) {
  if (/^\d+$/.test(host)) return true
  if (/0x[0-9a-f]/i.test(host)) return true
  var parts = host.split(".")
  if (parts.length >= 2 && parts.length <= 4) {
    var allNumeric = true
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i]
      if (!/^\d+$/.test(p)) { allNumeric = false; break }
      if (p.length > 1 && p.charAt(0) === "0") return true
    }
    if (allNumeric && parts.length < 4) return true
    if (allNumeric) return false
  }
  return false
}

function canonicalIpv6(host) {
  var h = String(host || "").toLowerCase()
  var tail = h.split(":").pop()
  if (tail.indexOf(".") !== -1) {
    var parts = tail.split(".")
    if (parts.length !== 4) return null
    var hi = (parseInt(parts[0], 10) << 8) + parseInt(parts[1], 10)
    var lo = (parseInt(parts[2], 10) << 8) + parseInt(parts[3], 10)
    if (isNaN(hi) || isNaN(lo)) return null
    var hiHex = ("0000" + hi.toString(16)).slice(-4)
    var loHex = ("0000" + lo.toString(16)).slice(-4)
    h = h.slice(0, h.length - tail.length) + hiHex + ":" + loHex
  }
  var groups
  var dbl = h.indexOf("::")
  if (dbl !== -1) {
    var sides = h.split("::")
    if (sides.length !== 2) return null
    var left = sides[0] === "" ? [] : sides[0].split(":")
    var right = sides[1] === "" ? [] : sides[1].split(":")
    var fill = 8 - left.length - right.length
    if (fill < 1) return null
    var mid = []
    for (var f = 0; f < fill; f++) mid.push("0")
    groups = left.concat(mid).concat(right)
  } else {
    groups = h.split(":")
  }
  if (groups.length !== 8) return null
  var out = []
  for (var j = 0; j < groups.length; j++) {
    var g = groups[j]
    if (!/^[0-9a-f]{1,4}$/.test(g)) return null
    out.push(("0000" + g).slice(-4))
  }
  return out.join(":")
}

function ipv4Private(host) {
  var parts = host.split(".")
  if (parts.length !== 4) return false
  var nums = []
  for (var i = 0; i < 4; i++) {
    if (!/^\d{1,3}$/.test(parts[i])) return false
    var v = parseInt(parts[i], 10)
    if (v > 255) return false
    nums.push(v)
  }
  var a = nums[0], b = nums[1], c = nums[2], d = nums[3]
  if (a === 0) return true
  if (a === 10) return true
  if (a === 100 && b >= 64 && b <= 127) return true
  if (a === 127) return true
  if (a === 169 && b === 254) return true
  if (a === 172 && b >= 16 && b <= 31) return true
  if (a === 192 && b === 0 && c === 0) return true
  if (a === 192 && b === 0 && c === 2) return true
  if (a === 192 && b === 88 && c === 99) return true
  if (a === 192 && b === 168) return true
  if (a === 198 && (b === 18 || b === 19)) return true
  if (a === 198 && b === 51 && c === 100) return true
  if (a === 203 && b === 0 && c === 113) return true
  if (a >= 224) return true
  return false
}

function isPrivateHost(host) {
  if (!host) return true
  for (var h = 0; h < host.length; h++) {
    if (host.charCodeAt(h) > 0x7e) return true
  }
  if (host.indexOf("%") !== -1) return true
  if (host === "localhost" || host.slice(-10) === ".localhost") return true
  var canon = canonicalIpv6(host)
  if (canon) {
    var groups = canon.split(":")
    var first = groups[0]
    if (first < "2000" || first > "3fff") return true
    if (first === "2002") return true
    if (first === "2001" && groups[1] === "0000") return true
    return false
  }
  if (isNumericIpLike(host)) return true
  if (ipv4Private(host)) return true
  return false
}

function hasDangerousChars(url) {
  var u = String(url || "")
  for (var i = 0; i < u.length; i++) {
    var code = u.charCodeAt(i)
    if (code <= 0x20 || code === 0x7f) return true
    if (code === 0x5c) return true
    if (code === 0x3002 || code === 0xff0e || code === 0xff61 || code === 0xff0f) return true
    if (code === 0x85 || code === 0xa0) return true
    if (code >= 0x2000 && code <= 0x200a) return true
    if (code === 0x2028 || code === 0x2029 || code === 0x202f || code === 0x205f || code === 0x3000) return true
  }
  return false
}

function safeUrl(url) {
  var u = String(url || "")
  if (hasDangerousChars(u)) return ""
  if (!/^https?:\/\//i.test(u)) return ""
  var host = urlHost(u)
  if (isPrivateHost(host)) return ""
  return u
}

function routeUrl(route, preferDark) {
  var url = ""
  if (typeof route === "string") url = route
  else if (route && typeof route === "object") {
    if (preferDark && route.dark) url = String(route.dark)
    else url = String(route.light || route.dark || "")
  }
  return safeUrl(url)
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

function variantModes(logo, format) {
  if (!logo || !logo.templates) return ["original"]
  var t = logo.templates
  var hasDark = Boolean(t[format + "_dark"])
  var hasLight = Boolean(t[format + "_light"])
  if (hasDark && hasLight) return ["original", "light", "dark"]
  if (hasDark) return ["original", "dark"]
  if (hasLight) return ["original", "light"]
  return ["original"]
}

function resolveVariant(logo, preferDark, format) {
  var modes = variantModes(logo, format)
  if (modes.length < 2) return "original"
  var want = preferDark ? "dark" : "light"
  return modes.indexOf(want) !== -1 ? want : "original"
}

function dashboardAssetUrl(logo, variant, format) {
  var t = logo.templates
  if (t) {
    var key = format
    if (variant === "dark" && t[format + "_dark"]) key = format + "_dark"
    else if (variant === "light" && t[format + "_light"]) key = format + "_light"
    var template = t[key]
    if (template) return String(template).split("{slug}").join(logo.slug)
  }
  if (logo.source === "simpleicons") {
    if (format === "svg") return SIMPLE_ICONS_CDN + logo.slug
    return ""
  }
  return DASHBOARD_CDN + format + "/" + logo.slug + "." + format
}

function variantTag(logo, variant) {
  var t = logo && logo.templates
  if (!t) return ""
  var f = primaryKind(logo)
  if (t[f + "_dark"] && t[f + "_light"])
    return variant === "dark" ? "-dark" : variant === "light" ? "-light" : ""
  return ""
}

function assetUrl(logo, variant, format) {
  if (!logo) return ""
  var url = ""
  if (logo.provider === "dashboard") url = dashboardAssetUrl(logo, variant, format)
  else if (format === "svg") url = routeUrl(logo.route, variant === "dark")
  return safeUrl(url)
}

function primaryKind(logo) {
  if (!logo) return "svg"
  if (logo.provider === "dashboard") return logo.hasSvg ? "svg" : "png"
  return "svg"
}

function primaryAssetUrl(logo, variant) {
  if (!logo) return ""
  return assetUrl(logo, variant, primaryKind(logo))
}

function logoCacheKey(logo, variant) {
  if (!logo) return ""
  if (logo.provider === "dashboard")
    return "dashboard-" + slugFor(logo.slug, logo.id) + variantTag(logo, variant)
  return slugFor(routeUrl(logo.route, variant === "dark"), logo.id).replace(/\.svg$/, "")
}

function readSourceUrl(logo, variant) {
  if (!logo) return ""
  if (logo.provider === "dashboard") return assetUrl(logo, variant, "svg")
  return safeUrl(SVGL_SVG_URL + slugFor(routeUrl(logo.route, variant === "dark"), logo.id))
}

function providerActions(provider) {
  if (!provider) return []
  if (Array.isArray(provider.actions)) return provider.actions
  if (provider.def && Array.isArray(provider.def.actions)) return provider.def.actions
  return []
}

function actionAvailable(provider, actionId, logo) {
  if (!provider || !actionId) return false
  if (!ACTIONS[actionId]) return false
  var actions = providerActions(provider)
  if (actions.indexOf(actionId) === -1) return false
  if (provider.id === "dashboard") {
    if (actionId === "svg" || actionId === "jsx" || actionId === "tsx" || actionId === "svgUrl")
      return Boolean(logo && logo.hasSvg)
    return true
  }
  return true
}

function typesFor(provider, logo) {
  if (!provider || !logo) return []
  if (provider.id === "svgl") return ["svg"]
  var types = []
  var formats = Array.isArray(logo.formats) ? logo.formats : []
  if (formats.indexOf("svg") !== -1) types.push("svg")
  if (formats.indexOf("png") !== -1) types.push("png")
  if (formats.indexOf("webp") !== -1) types.push("webp")
  return types
}

function actionsFor(provider, logo, type) {
  if (!provider || !type) return []
  var actions = providerActions(provider)
  var out = []
  for (var a = 0; a < actions.length; a++) {
    var id = actions[a]
    if (ACTIONS[id] && ACTIONS[id].type === type && actionAvailable(provider, id, logo))
      out.push(id)
  }
  return out
}

function actionAt(actions, index) {
  if (!actions || actions.length === 0) return ""
  var ai = Number(index) || 0
  return actions[Math.max(0, Math.min(ai, actions.length - 1))]
}

function actionLabel(actionId) {
  return ACTIONS[actionId] ? ACTIONS[actionId].label : ""
}

function sourceLabel(logo) {
  if (!logo || logo.provider !== "dashboard") return ""
  if (logo.source === "native") return "Dashboard Icons"
  if (logo.source === "selfhst") return "selfh.st"
  if (logo.source === "lobehub") return "LobeHub"
  if (logo.source === "simpleicons") return "Simple Icons"
  return ""
}

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
    value = value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    var camel = prop.replace(/-([a-z])/g, function(m, g) { return g.toUpperCase() })
    out.push('"' + camel + '": "' + value + '"')
  }
  return "{" + out.join(", ") + "}"
}

function escapeJsxText(svg) {
  var s = String(svg || "")
  var out = ""
  var inTag = false
  var inQuote = false
  var quoteChar = ""
  var inStyle = false
  var name = ""
  var readingName = false
  var i = 0
  var len = s.length
  while (i < len) {
    var c = s.charAt(i)
    if (inQuote) {
      out += c
      if (c === quoteChar) inQuote = false
      i++
      continue
    }
    if (inTag) {
      out += c
      if (c === '"' || c === "'") { inQuote = true; quoteChar = c }
      else if (c === "<") { inTag = true; name = ""; readingName = true }
      else if (c === ">") {
        inTag = false
        if (name === "style") inStyle = !inStyle
      } else if (readingName) {
        if (name === "" && c === "/") {}
        else if (/[A-Za-z0-9]/.test(c)) name += c
        else readingName = false
      }
      i++
      continue
    }
    if (c === "<") {
      inTag = true
      readingName = true
      name = ""
      out += c
      i++
      continue
    }
    if (inStyle) { out += c; i++; continue }
    if (c === "{") { out += "{'{'}"; i++; continue }
    if (c === "}") { out += "{'}'}"; i++; continue }
    out += c
    i++
  }
  return out
}

function cleanSvgForReact(svgCode) {
  var svg = String(svgCode || "")
  svg = svg.replace(/<!\[CDATA\[/g, "")
  svg = svg.replace(/\]\]>/g, "")
  svg = escapeJsxText(svg)
  svg = svg.replace(/<\?xml[^>]*\?>/g, "")
  svg = svg.replace(/<!DOCTYPE[^>]*>/gi, "")
  svg = svg.replace(/<!--[\s\S]*?-->/g, "")
  svg = svg.replace(/<metadata[\s\S]*?<\/metadata>/g, "")
  svg = svg.replace(/<sodipodi:namedview[\s\S]*?<\/sodipodi:namedview>/gi, "")
  svg = svg.replace(/<\s*style([^>]*)>([\s\S]*?)<\/\s*style>/g, function(m, attrs, content) {
    var cleaned = content.replace(/<!\[CDATA\[/g, "").replace(/\]\]>/g, "")
    return "<style" + attrs + ">{" + JSON.stringify(cleaned) + "}</style>"
  })
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
    SVGL_API_URL: SVGL_API_URL,
    SVGL_SVG_URL: SVGL_SVG_URL,
    SVGL_WEBSITE: SVGL_WEBSITE,
    DASHBOARD_CDN: DASHBOARD_CDN,
    DASHBOARD_SEARCH_URL: DASHBOARD_SEARCH_URL,
    DASHBOARD_WEBSITE: DASHBOARD_WEBSITE,
    SIMPLE_ICONS_CDN: SIMPLE_ICONS_CDN,
    TYPES: TYPES,
    ACTIONS: ACTIONS,
    providerDefs: providerDefs,
    parseConfig: parseConfig,
    normalizeFilter: normalizeFilter,
    parseProvider: parseProvider,
    normalizeFor: normalizeFor,
    categoriesOf: categoriesOf,
    filterLogos: filterLogos,
    routeUrl: routeUrl,
    slugFor: slugFor,
    isDark: isDark,
    variantModes: variantModes,
    resolveVariant: resolveVariant,
    safeUrl: safeUrl,
    styleToObject: styleToObject,
    escapeJsxText: escapeJsxText,
    assetUrl: assetUrl,
    primaryKind: primaryKind,
    primaryAssetUrl: primaryAssetUrl,
    logoCacheKey: logoCacheKey,
    readSourceUrl: readSourceUrl,
    actionAvailable: actionAvailable,
    typesFor: typesFor,
    actionsFor: actionsFor,
    actionAt: actionAt,
    actionLabel: actionLabel,
    sourceLabel: sourceLabel,
    shadcnCommand: shadcnCommand,
    componentName: componentName,
    reactifySvg: reactifySvg,
    toReactComponent: toReactComponent
  }
}