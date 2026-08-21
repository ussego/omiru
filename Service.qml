import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

QtObject {
  id: root

  property var manifest: null

  property var logos: []
  property var categories: []
  property string status: "idle"
  property string message: ""
  property string filter: "all"
  property var ready: ({})
  property int readyRevision: 0
  property int downloads: 0

  property bool expectedStop: false
  property var providers: []
  property var queue: []
  property var pending: ({})
  property var workers: []
  property var texts: ({})

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omiru"
  readonly property string libraryDir: root.stateDir + "/library"
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/omiru.json"
  readonly property int cacheMaxAgeMs: 30 * 60 * 1000
  readonly property int workerCount: 12
  property bool preferDark: false
  property bool hasPython3: false
  property int expectedTotal: 0
  property bool indexing: false
  property real indexProgress: 0

  property string catalogTransform: [
    "import json,sys,time",
    "raw=sys.stdin.read()",
    "data=json.loads(raw)",
    "items=data.get(\"items\",data) if isinstance(data,dict) else data",
    "items=items if isinstance(items,list) else list(data.values()) if isinstance(data,dict) else []",
    "print(json.dumps({\"fetchedAt\":int(time.time()*1000)},separators=(\",\",\":\")))",
    "pid=sys.argv[1] if len(sys.argv)>1 else \"\"",
    "if pid==\"dashboard\":",
    "    for it in items:",
    "        if not isinstance(it,dict): continue",
    "        d=it.get(\"data\") or {}",
    "        slug=str(it.get(\"slug\") or it.get(\"id\") or \"\").strip()",
    "        if not slug: continue",
    "        aliases=[str(a).strip() for a in (d.get(\"aliases\") or []) if str(a).strip()]",
    "        name=str(it.get(\"name\") or \"\").strip() or (aliases[0] if aliases else slug)",
    "        cats=[str(c) for c in (d.get(\"categories\") or [])]",
    "        src=str(it.get(\"source\") or \"native\").lower()",
    "        base=str(d.get(\"base\") or \"\")",
    "        ext=it.get(\"external\") or {}",
    "        fmts=[str(f) for f in (ext.get(\"formats\") or [])]",
    "        tpl=ext.get(\"url_templates\")",
    "        tpl=tpl if isinstance(tpl,dict) else None",
    "        brand=str(ext.get(\"brand_color\") or \"\")",
    "        print(json.dumps({\"s\":slug,\"n\":name,\"a\":aliases,\"c\":cats,\"r\":src,\"b\":base,\"f\":fmts,\"m\":tpl,\"k\":brand},separators=(\",\",\":\")))",
    "else:",
    "    for it in items:",
    "        if not isinstance(it,dict): continue",
    "        print(json.dumps({\"i\":it.get(\"id\"),\"t\":str(it.get(\"title\") or \"\").strip(),\"c\":it.get(\"category\"),\"r\":str(it.get(\"route\") or \"\"),\"u\":str(it.get(\"url\") or \"\"),\"b\":str(it.get(\"brandUrl\") or \"\")},separators=(\",\",\":\")))"
  ].join("\n")

  property Process pyDetectProc: Process {
    command: ["sh", "-c", "command -v python3 >/dev/null 2>&1"]
    running: true
    onExited: function(exitCode) { root.hasPython3 = exitCode === 0 }
  }

  function providerData(provider, raw) {
    var compact = Model.parseProviderCache(provider.id, raw)
    if (compact && compact.logos.length > 0)
      return { fetchedAt: compact.fetchedAt, logos: compact.logos, legacyItems: null }
    var parsed = Model.parseProvider(provider.id, raw)
    return { fetchedAt: parsed.fetchedAt, logos: Model.normalizeFor(provider.id, parsed.items), legacyItems: parsed.items }
  }

  function refresh(force) {
    for (var i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (provider.enabled) root.refreshProvider(provider, force)
    }
  }

  function refreshProvider(provider, force) {
    if (!provider || root.expectedStop || !provider.enabled) return
    if (provider.loading) return
    if (!force && provider.fetchedAt > 0 && Date.now() - provider.fetchedAt < root.cacheMaxAgeMs) return
    provider.loading = true
    provider.status = "loading"
    provider.message = ""
    provider.proc.command = root.fetchCommand(provider)
    provider.proc.running = true
    root.updateStatus()
  }

  function fetchCommand(provider) {
    if (root.hasPython3) {
      return ["bash", "-c",
        'curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-redirs 5 --max-time 30 --max-filesize 33554432 -- "$1" | python3 -c \'' + root.catalogTransform + '\' "$2"',
        "omiru-fetch", provider.def.catalogUrl, provider.id]
    }
    return ["curl", "-fsSL", "--max-time", "30", "--max-filesize", "33554432",
      "--proto", "=http,https", "--proto-redir", "=http,https", "--max-redirs", "5",
      provider.def.catalogUrl]
  }

  function clearCache() {
    if (root.clearProc.running) return
    root.expectedStop = true
    for (var i = 0; i < root.workers.length; i++) {
      var worker = root.workers[i]
      if (worker) {
        worker.running = false
        worker.item = null
      }
    }
    root.readProc.running = false
    for (i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (provider.proc) provider.proc.running = false
    }
    root.rasterProc.running = false
    root.scanProc.running = false

    root.queue = []
    root.pending = {}
    root.ready = {}
    root.readyRevision++
    root.texts = {}
    root.downloads = 0
    root.rasterStarted = false

    for (i = 0; i < root.providers.length; i++) {
      var prov = root.providers[i]
      prov.fetchedAt = 0
      prov.logos = []
      prov.loading = false
      prov.status = "idle"
      prov.message = ""
    }
    root.logos = []
    root.categories = []
    root.updateStatus()

    root.clearProc.command = ["bash", "-c",
      'rm -rf -- "$1" && mkdir -p -- "$1"',
      "omiru-clear", root.stateDir]
    root.clearProc.running = true
  }

  function applyConfig(raw) {
    if (root.expectedStop) return
    var cfg = Model.parseConfig(raw)
    var defs = Model.providerDefs()
    var next = []
    for (var i = 0; i < defs.length; i++) {
      var def = defs[i]
      var existing = null
      for (var j = 0; j < root.providers.length; j++) {
        if (root.providers[j].id === def.id) existing = root.providers[j]
      }
      var provider = existing || root.createProvider(def)
      provider.enabled = cfg.enabledIds.indexOf(def.id) !== -1
      provider.touched = cfg.touched.indexOf(def.id) !== -1
      provider.isNew = !cfg.fresh && !provider.touched
      next.push(provider)
    }
    root.providers = next
    root.filter = Model.normalizeFilter(cfg.filter)
    root.rebuildProviders()
    if (!String(raw || "").trim()) root.persistConfig()
  }

  function setFilter(id) {
    root.filter = Model.normalizeFilter(id)
    root.persistConfig()
  }

  function toggleProviderEnabled(id) {
    var provider = root.providerById(id)
    if (!provider) return
    root.setProviderEnabled(id, !provider.enabled)
  }

  function setProviderEnabled(id, enabled) {
    var provider = root.providerById(id)
    if (!provider || provider.enabled === Boolean(enabled)) return
    provider.touched = true
    provider.isNew = false
    provider.enabled = Boolean(enabled)
    if (!provider.enabled && root.filter === id) root.filter = "all"
    if (provider.enabled) root.refreshProvider(provider, false)
    root.rebuildProviders()
    root.providers = root.providers.slice()
    root.persistConfig()
  }

  function createProvider(def) {
    var provider = {
      id: def.id,
      name: def.name,
      def: def,
      enabled: true,
      touched: false,
      isNew: false,
      loading: false,
      status: "idle",
      message: "",
      fetchedAt: 0,
      items: [],
      logos: [],
      file: null,
      loadProc: null,
      proc: null
    }
    provider.file = root.cacheFileComponent.createObject(root, { providerId: def.id })
    provider.file.path = root.stateDir + "/" + def.cacheFile
    provider.loadProc = root.cacheLoadComponent.createObject(root, { providerId: def.id })
    provider.proc = root.catalogProcComponent.createObject(root, { providerId: def.id })
    provider.loadProc.command = ["cat", root.stateDir + "/" + def.cacheFile]
    provider.loadProc.running = true
    return provider
  }

  function providerById(id) {
    for (var i = 0; i < root.providers.length; i++) {
      if (root.providers[i].id === id) return root.providers[i]
    }
    return null
  }

  function persistConfig() {
    var ids = []
    var touched = []
    for (var i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (provider.enabled) ids.push(provider.id)
      if (provider.touched) touched.push(provider.id)
    }
    root.configFile.setText(JSON.stringify({ version: 2, providers: ids, filter: root.filter, touched: touched }, null, 2) + "\n")
  }

  function rebuildProviders() {
    var merged = []
    for (var i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (provider.enabled) merged = merged.concat(provider.logos)
    }
    root.logos = merged
    root.categories = Model.categoriesOf(merged)
    root.updateStatus()
    root.prefetch()
    gc()
  }

  function updateStatus() {
    var loading = false
    var error = false
    var messages = []
    for (var i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (!provider.enabled) continue
      if (provider.status === "loading") loading = true
      if (provider.status === "error") error = true
      if (provider.status === "error" && provider.message) messages.push(provider.message)
    }
    root.message = messages.join("\n")
    if (root.logos.length > 0) root.status = "ready"
    else if (loading) root.status = "loading"
    else if (error) root.status = "error"
    else root.status = "idle"
  }

  function loadCache(provider, raw) {
    if (!provider || !provider.enabled || root.expectedStop) return
    var data = root.providerData(provider, raw)
    if (data.logos.length > 0) {
      provider.fetchedAt = data.fetchedAt
      provider.logos = data.logos
      provider.status = "ready"
      provider.message = ""
      root.rebuildProviders()
    }
    root.refreshProvider(provider, false)
  }

  function applyFetch(provider, raw) {
    if (!provider || root.expectedStop) return
    provider.loading = false
    var data = root.providerData(provider, raw)
    if (data.logos.length === 0) {
      if (provider.logos.length === 0) {
        provider.status = "error"
        provider.message = "Couldn't reach " + provider.name + " — Ctrl+R to retry"
      } else {
        provider.status = "ready"
        provider.message = ""
      }
      root.updateStatus()
      return
    }
    provider.fetchedAt = data.fetchedAt || Date.now()
    provider.logos = data.logos
    provider.status = "ready"
    provider.message = ""
    if (data.legacyItems)
      provider.file.setText(JSON.stringify({ fetchedAt: provider.fetchedAt, items: data.legacyItems }) + "\n")
    else
      provider.file.setText(String(raw || "") + "\n")
    root.rebuildProviders()
  }

  function applyScan(raw) {
    var lines = String(raw || "").split("\n")
    var next = {}
    for (var i = 0; i < lines.length; i++) {
      var name = lines[i].trim()
      if (!name) continue
      if (name.slice(-8) === ".svg.png") {
        next[name.slice(0, -8)] = "png"
      } else if (name.slice(-4) === ".svg") {
        if (next[name.slice(0, -4)] !== "png") next[name.slice(0, -4)] = "svg"
      } else if (name.slice(-4) === ".png") {
        if (!next[name.slice(0, -4)]) next[name.slice(0, -4)] = "raw"
      }
    }
    root.ready = next
    root.readyRevision++
  }

  function enqueue(logo, variant, priority) {
    var key = Model.logoCacheKey(logo, variant)
    if (!key) return
    var kind = Model.primaryKind(logo)
    var have = root.ready[key]
    if (have && (have !== "raw" || kind === "png")) return
    if (root.pending[key]) return
    var url = Model.primaryAssetUrl(logo, variant)
    if (!url) return
    root.pending[key] = true
    var item = {
      url: url,
      key: key,
      kind: kind,
      dest: root.libraryDir + "/" + key + (kind === "png" ? ".png" : ".svg")
    }
    if (priority) root.queue.unshift(item)
    else root.queue.push(item)
    root.pump()
  }

  function ensureLogo(logo, variant) {
    if (!logo) return
    root.enqueue(logo, variant, true)
  }

  function prefetch() {
    if (root.expectedStop) return
    var needed = {}
    var gateOpen = true
    for (var i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (!provider.enabled) continue
      var status = provider.status
      if (status === "loading" || status === "idle") {
        gateOpen = false
        continue
      }
      var logos = provider.logos
      if (logos.length === 0 || !gateOpen) continue
      if (i === 0) {
        for (var j = logos.length - 1; j >= 0; j--) {
          var logo = logos[j]
          var variant = Model.resolveVariant(logo, root.preferDark, Model.primaryKind(logo))
          var key = Model.logoCacheKey(logo, variant)
          if (key) needed[key] = 1
          root.enqueue(logo, variant, true)
        }
      } else {
        for (var k = 0; k < logos.length; k++) {
          var l2 = logos[k]
          var v2 = Model.resolveVariant(l2, root.preferDark, Model.primaryKind(l2))
          var k2 = Model.logoCacheKey(l2, v2)
          if (k2) needed[k2] = 1
          root.enqueue(l2, v2, false)
        }
      }
    }
    root.expectedTotal = root.countKeys(needed)
    root.updateIndexProgress()
  }

  function countKeys(obj) {
    var n = 0
    for (var k in obj) n++
    return n
  }

  function workersBusy() {
    for (var i = 0; i < root.workers.length; i++) {
      if (root.workers[i].running) return true
    }
    return false
  }

  function updateIndexProgress() {
    var total = root.expectedTotal
    var ready = root.countKeys(root.ready)
    var pendingWork = root.queue.length > 0 || root.workersBusy()
    root.indexing = total > 0 && ready < total && pendingWork
    root.indexProgress = total > 0 ? Math.min(1, ready / total) : 0
  }

  function pump() {
    for (var i = 0; i < root.workers.length && root.queue.length > 0; i++) {
      var worker = root.workers[i]
      if (worker.running || worker.item) continue
      var item = root.queue.shift()
      worker.item = item
      worker.command = ["bash", "-c",
        'D="${1%/*}"; mkdir -p -- "$D" || exit 1\n'
        + 'curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-redirs 5 --max-time 15 --max-filesize 5242880 -o "$1" -- "$2" || exit 1\n'
        + 'if [ "$3" != "png" ] && command -v rsvg-convert >/dev/null 2>&1 && rsvg-convert -w 192 -o "$1.png" "$1" 2>/dev/null; then\n'
        + '  exit 42\n'
        + 'fi\n'
        + 'exit 0',
        "omiru-download", item.dest, item.url, item.kind]
      worker.running = true
    }
  }

  function workerDone(worker, code) {
    if (root.expectedStop) return
    var item = worker.item
    worker.item = null
    if (!item) return
    if (code === 0 || code === 42) {
      root.ready[item.key] = code === 42 ? "png" : item.kind === "png" ? "raw" : "svg"
      root.readyRevision++
      root.downloads++
    } else {
      delete root.pending[item.key]
    }
    root.pump()
  }

  function copySvg(logo, variant) {
    var key = Model.logoCacheKey(logo, variant)
    if (!key) return
    var url = Model.primaryAssetUrl(logo, variant)
    if (!url) return
    var kind = Model.primaryKind(logo)
    var path = root.libraryDir + "/" + key + (kind === "png" ? ".png" : ".svg")
    var mime = kind === "png" ? "image/png" : "text/plain"
    Quickshell.execDetached(["bash", "-c",
      'if [ -f "$1" ]; then wl-copy --type "$3" < "$1"; else curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-redirs 5 --max-time 15 --max-filesize 5242880 -- "$2" | wl-copy --type "$3"; fi',
      "omiru-copy", path, url, mime])
  }

  function copyImage(logo, variant, format) {
    var key = Model.logoCacheKey(logo, variant)
    if (!key) return
    var url = Model.assetUrl(logo, variant, format)
    if (!url) return
    var path = root.libraryDir + "/" + key + "." + format
    Quickshell.execDetached(["bash", "-c",
      'D="${1%/*}"; mkdir -p -- "$D" || exit 1\n'
      + 'if [ ! -f "$1" ]; then curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-redirs 5 --max-time 15 --max-filesize 5242880 -o "$1" -- "$2" || exit 1; fi\n'
      + 'wl-copy --type "image/' + format + '" < "$1"',
      "omiru-copy", path, url])
  }

  function copyAction(logo, variant, actionId) {
    if (!logo || !actionId) return
    if (actionId === "svg") {
      root.copySvg(logo, variant)
    } else if (actionId === "png" || actionId === "webp") {
      root.copyImage(logo, variant, actionId)
    } else if (actionId === "jsx" || actionId === "tsx") {
      root.copyReact(logo, variant, actionId)
    } else if (actionId === "shadcn") {
      root.copyText(Model.shadcnCommand(logo.title))
    } else if (actionId === "svgUrl" || actionId === "pngUrl" || actionId === "webpUrl") {
      var format = actionId.slice(0, -3).toLowerCase()
      root.copyText(Model.assetUrl(logo, variant, format))
    }
  }

  function copyReact(logo, variant, format) {
    var key = Model.logoCacheKey(logo, variant)
    if (!key) return
    if (root.texts[key] !== undefined) {
      root.copyText(Model.toReactComponent(root.texts[key], logo.title, format === "tsx"))
      return
    }
    if (root.readProc.running) return
    root.readProc.request = { key: key, title: logo.title, format: format }
    root.readProc.command = ["bash", "-c",
      'curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-redirs 5 --max-time 15 --max-filesize 5242880 -- "$3" || { [ -f "$1" ] && cat -- "$1"; } || curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-redirs 5 --max-time 15 --max-filesize 5242880 -- "$2"',
      "omiru-read", root.libraryDir + "/" + key + ".svg",
      Model.routeUrl(logo.route, variant === "dark"), Model.readSourceUrl(logo, variant)]
    root.readProc.running = true
  }

  function readDone(request, text) {
    if (!request) return
    if (text) {
      var next = {}
      for (var k in root.texts) next[k] = root.texts[k]
      next[request.key] = text
      root.texts = next
      root.copyText(Model.toReactComponent(text, request.title, request.format === "tsx"))
    }
  }

  function copyText(value) {
    if (!value) return
    value = String(value)
    if (value.charAt(0) === "-") return
    Quickshell.execDetached(["wl-copy", value])
  }

  function openUrl(url) {
    if (!url) return
    if (!Model.safeUrl(url)) return
    Quickshell.execDetached(["xdg-open", String(url)])
  }

  property Process initProc: Process {
    command: ["mkdir", "-p", root.libraryDir]
    running: true
    onExited: function(exitCode) {
      if (exitCode === 0) root.scanProc.running = true
    }
  }

  property Process scanProc: Process {
    command: ["ls", "-1", "--", root.libraryDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.expectedStop) return
        root.applyScan(text)
        if (!root.rasterStarted) {
          root.rasterStarted = true
          root.rasterProc.running = true
        }
      }
    }
  }

  property bool rasterStarted: false

  property Timer indexTimer: Timer {
    interval: 400
    repeat: true
    running: true
    onTriggered: root.updateIndexProgress()
  }

  property Process rasterProc: Process {
    command: ["bash", "-c",
      'command -v rsvg-convert >/dev/null 2>&1 || exit 0\n'
      + 'for f in "$1"/*.svg; do\n'
      + '  [ -f "$f" ] || continue\n'
      + '  [ -f "$f.png" ] && continue\n'
      + '  rsvg-convert -w 192 -o "$f.png" "$f" 2>/dev/null || true\n'
      + 'done\n'
      + 'exit 0',
      "omiru-raster", root.libraryDir]
    onExited: function(exitCode) {
      if (!root.expectedStop) root.scanProc.running = true
    }
  }

  property Component cacheFileComponent: Component {
    FileView {
      property string providerId: ""
      atomicWrites: true
      printErrors: false
    }
  }

  property Component cacheLoadComponent: Component {
    Process {
      property string providerId: ""
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (!root.expectedStop) root.loadCache(root.providerById(providerId), text)
        }
      }
      onExited: function(exitCode) {
        if (!root.expectedStop && exitCode !== 0)
          root.refreshProvider(root.providerById(providerId), false)
      }
    }
  }

  property Component catalogProcComponent: Component {
    Process {
      property string providerId: ""
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: if (!root.expectedStop) root.applyFetch(root.providerById(providerId), text)
      }
    }
  }

  property FileView configFile: FileView {
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
  }

  property Process readProc: Process {
    property var request: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.expectedStop) return
        root.readDone(readProc.request, text)
        readProc.request = null
      }
    }
  }

  property Process clearProc: Process {
    command: ["true"]
    onExited: function(exitCode) {
      root.expectedStop = false
      root.refresh(true)
    }
  }

  property Component workerComponent: Component {
    Process {
      id: worker
      property var item: null
      onExited: function(exitCode) { root.workerDone(worker, exitCode) }
    }
  }

  Component.onCompleted: {
    for (var i = 0; i < root.workerCount; i++)
      root.workers.push(root.workerComponent.createObject(root))
    Quickshell.execDetached(["hyprctl", "keyword", "layerrule", "noanim,ussego-omiru"])
  }

  Component.onDestruction: {
    root.expectedStop = true
    for (var i = 0; i < root.workers.length; i++) {
      var worker = root.workers[i]
      if (worker) {
        worker.running = false
        worker.destroy()
      }
    }
    for (i = 0; i < root.providers.length; i++) {
      var provider = root.providers[i]
      if (provider.file) provider.file.destroy()
      if (provider.loadProc) provider.loadProc.destroy()
      if (provider.proc) provider.proc.destroy()
    }
  }
}