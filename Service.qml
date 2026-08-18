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
  property var ready: ({})
  property int downloads: 0

  property bool expectedStop: false
  property int fetchedAt: 0
  property var queue: []
  property var pending: ({})
  property var workers: []
  property var texts: ({})

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omiru"
  readonly property string libraryDir: root.stateDir + "/library"
  readonly property string catalogPath: root.stateDir + "/svgl.json"
  readonly property int cacheMaxAgeMs: 30 * 60 * 1000
  readonly property int workerCount: 4

  function refresh(force) {
    if (root.catalogProc.running) return
    if (!force && root.fetchedAt > 0 && Date.now() - root.fetchedAt < root.cacheMaxAgeMs) return
    root.status = "loading"
    root.message = ""
    root.catalogProc.running = true
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
    root.catalogProc.running = false
    root.rasterProc.running = false
    root.scanProc.running = false

    root.queue = []
    root.pending = {}
    root.ready = {}
    root.texts = {}
    root.fetchedAt = 0
    root.logos = []
    root.categories = []
    root.downloads = 0
    root.rasterStarted = false

    root.clearProc.command = ["bash", "-c",
      'rm -rf -- "$1" && mkdir -p -- "$1" && rm -f -- "$2"',
      "omiru-clear", root.libraryDir, root.catalogPath]
    root.clearProc.running = true
  }

  function applyFetch(raw) {
    var parsed = Model.parseSvgl(raw)
    var nextLogos = Model.normalizeLogos(parsed.items)
    if (nextLogos.length === 0) {
      if (root.logos.length === 0) {
        root.status = "error"
        root.message = "Couldn't reach svgl.app — Ctrl+R to retry"
      } else {
        root.status = "ready"
      }
      return
    }
    root.fetchedAt = parsed.fetchedAt || Date.now()
    root.logos = nextLogos
    root.categories = Model.categoriesOf(nextLogos)
    root.status = "ready"
    root.message = ""
    root.catalogFile.setText(JSON.stringify({ fetchedAt: root.fetchedAt, items: parsed.items }) + "\n")
  }

  function loadCache(raw) {
    var parsed = Model.parseSvgl(raw)
    var cachedLogos = Model.normalizeLogos(parsed.items)
    if (cachedLogos.length > 0) {
      root.fetchedAt = parsed.fetchedAt
      root.logos = cachedLogos
      root.categories = Model.categoriesOf(cachedLogos)
      root.status = "ready"
    }
    root.refresh(false)
  }

  function applyScan(raw) {
    var lines = String(raw || "").split("\n")
    var next = {}
    for (var i = 0; i < lines.length; i++) {
      var name = lines[i].trim()
      if (!name) continue
      if (name.slice(-8) === ".svg.png") {
        next[name.slice(0, -4)] = "png"
      } else if (name.slice(-4) === ".svg" && next[name] !== "png") {
        next[name] = "svg"
      }
    }
    root.ready = next
  }

  function ensureLogo(logo, preferDark) {
    if (!logo) return
    var url = Model.routeUrl(logo.route, preferDark)
    if (!url) return
    var slug = Model.slugFor(url, logo.id)
    if (root.ready[slug] || root.pending[slug]) return
    root.pending[slug] = true
    root.queue.push({ url: url, slug: slug, dest: root.libraryDir + "/" + slug })
    root.pump()
  }

  function pathFor(logo, preferDark) {
    var url = Model.routeUrl(logo.route, preferDark)
    if (!url) return ""
    return root.libraryDir + "/" + Model.slugFor(url, logo.id)
  }

  function pump() {
    for (var i = 0; i < root.workers.length && root.queue.length > 0; i++) {
      var worker = root.workers[i]
      if (worker.running || worker.item) continue
      var item = root.queue.shift()
      worker.item = item
      worker.command = ["bash", "-c",
        'curl -fsSL --max-time 15 -o "$1" -- "$2" || exit 1\n'
        + 'if command -v rsvg-convert >/dev/null 2>&1 && rsvg-convert -w 192 -o "$1.png" "$1" 2>/dev/null; then\n'
        + '  exit 42\n'
        + 'fi\n'
        + 'exit 0',
        "omiru-download", item.dest, item.url]
      worker.running = true
    }
  }

  function workerDone(worker, code) {
    if (root.expectedStop) return
    var item = worker.item
    worker.item = null
    if (!item) return
    if (code === 0 || code === 42) {
      var next = {}
      for (var k in root.ready) next[k] = root.ready[k]
      next[item.slug] = code === 42 ? "png" : (next[item.slug] === "png" ? "png" : "svg")
      root.ready = next
      root.downloads++
    } else {
      delete root.pending[item.slug]
    }
    root.pump()
  }

  function copySvg(logo, preferDark) {
    var url = Model.routeUrl(logo.route, preferDark)
    if (!url) return
    var path = root.libraryDir + "/" + Model.slugFor(url, logo.id)
    Quickshell.execDetached(["bash", "-c",
      'if [ -f "$1" ]; then wl-copy < "$1"; else curl -fsSL --max-time 15 -- "$2" | wl-copy; fi',
      "omiru-copy", path, url])
  }

  function copyFormatted(logo, preferDark, format) {
    if (!logo) return
    if (format === "shadcn") {
      root.copyText(Model.shadcnCommand(logo.title))
      return
    }
    if (format === "jsx" || format === "tsx") {
      var url = Model.routeUrl(logo.route, preferDark)
      if (!url) return
      var slug = Model.slugFor(url, logo.id)
      if (root.texts[slug] !== undefined) {
        root.copyText(Model.toReactComponent(root.texts[slug], logo.title, format === "tsx"))
        return
      }
      if (root.readProc.running) return
      root.readProc.request = { slug: slug, title: logo.title, format: format }
      root.readProc.command = ["bash", "-c",
        'curl -fsSL --max-time 15 -- "$3" || { [ -f "$1" ] && cat -- "$1"; } || curl -fsSL --max-time 15 -- "$2"',
        "omiru-read", root.libraryDir + "/" + slug, url, Model.API_URL + "/svg/" + slug]
      root.readProc.running = true
      return
    }
    root.copySvg(logo, preferDark)
  }

  function readDone(request, text) {
    if (!request) return
    if (text) {
      var next = {}
      for (var k in root.texts) next[k] = root.texts[k]
      next[request.slug] = text
      root.texts = next
      root.copyText(Model.toReactComponent(text, request.title, request.format === "tsx"))
    }
  }

  function copyText(value) {
    if (!value) return
    Quickshell.execDetached(["wl-copy", value])
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", url])
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

  property Process catalogProc: Process {
    command: ["curl", "-fsSL", "--max-time", "30", Model.API_URL]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (!root.expectedStop) root.applyFetch(text)
    }
  }

  property FileView catalogFile: FileView {
    path: root.catalogPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadCache(text())
    onLoadFailed: root.refresh(false)
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
  }
}
