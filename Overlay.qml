import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property string categoryName: "all"
  property bool categoryPicker: false
  property string categorySearch: ""
  property int categoryPickIndex: 0
  property bool providerPicker: false
  property int providerPickIndex: 0
  property bool commandPalette: false
  property string commandSearch: ""
  property int commandPickIndex: 0
  property int topCategoryCount: 8
  property string providerFilter: "all"
  property int typeIndex: 0
  property int actionIndex: 0
  property string lastProviderId: ""
  property var typeMemory: ({})
  property var actionMemory: ({})
  property var detail: null
  property var visibleLogos: []

  readonly property var contextLogo: root.detail !== null ? root.detail : root.logoAt(root.selectedIndex)
  readonly property var contextProvider: root.providerFor(root.contextLogo)
  readonly property var contextTypes: root.contextProvider && root.contextLogo
    ? Model.typesFor(root.contextProvider, root.contextLogo) : []
  readonly property var contextActions: root.contextProvider && root.contextLogo
    ? Model.actionsFor(root.contextProvider, root.contextLogo, root.currentType()) : []
  readonly property string activeActionId: Model.actionAt(root.contextActions, root.actionIndex)
  readonly property string activeActionLabel: Model.actionLabel(root.activeActionId)

  property int variantIndex: 0
  property string lastDisabledId: ""
  readonly property var detailVariantModes: root.detail
    ? Model.variantModes(root.detail, root.currentType()) : []
  readonly property string detailVariant: (function() {
    var modes = root.detailVariantModes
    if (modes.length === 0) return "original"
    var i = Math.max(0, Math.min(root.variantIndex, modes.length - 1))
    return modes[i]
  })()

  readonly property var categoryRowModel: (function() {
    var cats = root.svc ? root.svc.categories : []
    var out = []
    for (var i = 0; i < cats.length && i < root.topCategoryCount; i++) out.push(cats[i])
    out.push({ more: true })
    return out
  })()

  readonly property var categoryPickModel: (function() {
    var cats = root.svc ? root.svc.categories : []
    var needle = root.categorySearch.trim().toLowerCase()
    if (!needle) return cats
    var out = []
    for (var i = 0; i < cats.length; i++) {
      if (cats[i].name.toLowerCase().indexOf(needle) !== -1) out.push(cats[i])
    }
    return out
  })()

  readonly property var providerPickModel: (function() {
    var out = []
    if (root.svc) {
      for (var i = 0; i < root.svc.providers.length; i++) {
        var p = root.svc.providers[i]
        out.push({ id: p.id, name: p.name, enabled: p.enabled, isNew: p.isNew })
      }
    }
    return out
  })()

  readonly property string pluginId: (root.manifest && root.manifest.id) || "ussego.omiru"
  readonly property var svc: root.service || (root.shell && typeof root.shell.serviceFor === "function"
    ? root.shell.serviceFor(root.pluginId) : null)

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int chipsHeight: Style.space(30)
  property int providersHeight: Style.space(30)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(875), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)
  property int minCellWidth: Style.space(104)
  property int cellHeight: Style.space(88)

  readonly property bool preferDark: Model.isDark(root.background)
  readonly property int columns: Math.max(1, Math.floor(contentArea.width / root.minCellWidth))
  readonly property int cellWidth: Math.max(root.minCellWidth, Math.floor(contentArea.width / root.columns))
  readonly property int dialogVerticalOffset: (function() {
    var top = card ? card.contentTopInset : 0
    var bottom = card ? card.contentBottomInset : 0
    return -Math.round((2 * top + root.headerHeight + 3 * root.contentSpacing + root.providersHeight + root.chipsHeight - bottom) / 2)
  })()
  readonly property bool catalogLoading: root.svc === null || (function() {
    if (root.svc.status === "loading" && root.svc.logos.length === 0) return true
    for (var i = 0; i < root.svc.providers.length; i++) {
      var p = root.svc.providers[i]
      if (p.enabled && (p.status === "loading" || p.status === "idle") && p.logos.length === 0) return true
    }
    return false
  })()
  readonly property bool showProviderBadges: root.providerFilter === "all" && root.svc !== null && (function() {
    var n = 0
    for (var i = 0; i < root.svc.providers.length; i++) {
      if (root.svc.providers[i].enabled) n++
    }
    return n > 1
  })()
  readonly property bool catalogError: root.svc !== null && root.svc.status === "error" && root.svc.logos.length === 0
  readonly property string stateMessage: root.catalogLoading
    ? "Loading icons…"
    : root.catalogError
      ? (root.svc.message || "Couldn't reach the icon providers")
      : "No matches for “" + root.filterText + "”"

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    var query = typeof payload.query === "string" ? payload.query : ""
    var category = typeof payload.category === "string" && payload.category ? payload.category : "all"
    var provider = typeof payload.provider === "string" && payload.provider
      ? payload.provider
      : (root.svc ? root.svc.filter : "all")
    var changed = query !== root.filterText
      || category !== root.categoryName
      || provider !== root.providerFilter
      || root.detail !== null
    root.filterText = query
    root.categoryName = category
    root.providerFilter = provider
    root.detail = null
    root.selectedIndex = 0
    root.cursorActive = true
    if (changed) root.rebuildDisplay()
    root.opened = true
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.detail = null
  }

  function dismiss() {
    root.opened = false
    root.detail = null
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
    else root.close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refresh() {
    if (root.svc) root.svc.refresh(true)
  }

  function clearCache() {
    if (root.svc) root.svc.clearCache()
  }

  function rebuildDisplay() {
    var logos = []
    if (root.svc) {
      var gateOpen = true
      for (var i = 0; i < root.svc.providers.length; i++) {
        var provider = root.svc.providers[i]
        if (!provider.enabled) continue
        var status = provider.status
        if (status === "loading" || status === "idle") {
          if (provider.logos.length === 0) gateOpen = false
          else if (gateOpen) logos = logos.concat(provider.logos)
        } else if (status === "ready") {
          if (gateOpen) logos = logos.concat(provider.logos)
        }
      }
    }
    var out = Model.filterLogos(logos, root.filterText, root.categoryName, root.providerFilter, 10000)
    root.visibleLogos = out

    if (root.visibleLogos.length === 0) root.selectedIndex = 0
    else if (root.selectedIndex >= root.visibleLogos.length) root.selectedIndex = root.visibleLogos.length - 1
    else if (root.selectedIndex < 0) root.selectedIndex = 0
    root.cursorActive = root.visibleLogos.length > 0
    root.syncSelection()
    root.clampAction()

    Qt.callLater(function() {
      if (root.visibleLogos.length > 0) logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.filterTimer.restart()
  }

  function categoryIndexFor(name) {
    var cats = root.svc ? root.svc.categories : []
    for (var i = 0; i < cats.length; i++) {
      if (cats[i].name.toLowerCase() === String(name).toLowerCase()) return i
    }
    return 0
  }

  function setCategory(name) {
    root.categoryName = name
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
    chipsList.positionViewAtIndex(root.categoryIndexFor(name), ListView.Contain)
  }

  function openCategoryPicker() {
    root.categoryPicker = true
    root.categorySearch = ""
    root.categoryPickIndex = root.categoryIndexFor(root.categoryName)
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function closeCategoryPicker() {
    root.categoryPicker = false
    root.categorySearch = ""
  }

  function moveCategoryPick(delta) {
    var model = root.categoryPickModel
    if (!model || model.length === 0) return
    root.categoryPickIndex = (root.categoryPickIndex + delta + model.length) % model.length
    categoryPickList.positionViewAtIndex(root.categoryPickIndex, ListView.Contain)
  }

  function pickCategoryAt(index) {
    var model = root.categoryPickModel
    if (!model || index < 0 || index >= model.length) return
    root.setCategory(model[index].name)
    root.closeCategoryPicker()
  }

  function providerPickIndexFor(id) {
    var model = root.providerPickModel
    for (var i = 0; i < model.length; i++) {
      if (String(model[i].id).toLowerCase() === String(id).toLowerCase()) return i
    }
    return 0
  }

  function openProviderPicker() {
    root.providerPicker = true
    root.providerPickIndex = root.providerPickIndexFor(root.providerFilter)
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function closeProviderPicker() {
    root.providerPicker = false
  }

  function moveProviderPick(delta) {
    var model = root.providerPickModel
    if (!model || model.length === 0) return
    root.providerPickIndex = (root.providerPickIndex + delta + model.length) % model.length
    providerPickList.positionViewAtIndex(root.providerPickIndex, ListView.Contain)
  }

  function flipProviderPickAt(index) {
    var model = root.providerPickModel
    if (!model || index < 0 || index >= model.length) return
    var entry = model[index]
    var provider = root.providerAt(entry.id)
    if (!provider) return
    if (provider.enabled) {
      root.disableProvider(entry.id)
    } else {
      root.lastDisabledId = entry.id
      root.svc.toggleProviderEnabled(entry.id)
    }
  }

  function currentType() {
    var types = root.contextTypes
    if (types.length === 0) return ""
    return types[Math.max(0, Math.min(root.typeIndex, types.length - 1))]
  }

  function cycleType(delta) {
    var types = root.contextTypes
    if (types.length === 0) return
    var count = types.length
    var step = Number(delta)
    if (!isFinite(step)) step = 1
    root.typeIndex = (root.typeIndex + step + count * 100) % count
    root.actionIndex = 0
  }

  function cycleAction(delta) {
    var actions = root.contextActions
    if (actions.length === 0) return
    var count = actions.length
    var step = Number(delta)
    if (!isFinite(step)) step = 1
    root.actionIndex = (root.actionIndex + step + count * 100) % count
  }

  function pickAction(number) {
    var actions = root.contextActions
    if (number >= 1 && number <= actions.length) root.actionIndex = number - 1
  }

  function providerKey() {
    var logo = root.detail !== null ? root.detail : root.logoAt(root.selectedIndex)
    var provider = root.providerFor(logo)
    return provider ? provider.id : "all"
  }

  function syncSelection() {
    var key = root.providerKey()
    if (!key || key === "all" || key === root.lastProviderId) return
    if (root.lastProviderId) {
      root.typeMemory[root.lastProviderId] = root.typeIndex
      root.actionMemory[root.lastProviderId] = root.actionIndex
    }
    root.lastProviderId = key
    if (root.typeMemory[key] !== undefined && root.actionMemory[key] !== undefined) {
      root.typeIndex = root.typeMemory[key]
      root.actionIndex = root.actionMemory[key]
    } else {
      root.typeIndex = 0
      root.actionIndex = 0
    }
  }

  function clampAction() {
    var logo = root.detail !== null ? root.detail : root.logoAt(root.selectedIndex)
    var provider = root.providerFor(logo)
    var types = provider && logo ? Model.typesFor(provider, logo) : []
    if (types.length === 0) {
      root.typeIndex = 0
      root.actionIndex = 0
      return
    }
    if (root.typeIndex >= types.length) root.typeIndex = types.length - 1
    if (root.typeIndex < 0) root.typeIndex = 0
    var type = types[root.typeIndex]
    var actions = provider && logo ? Model.actionsFor(provider, logo, type) : []
    if (actions.length === 0) {
      root.actionIndex = 0
      return
    }
    if (root.actionIndex >= actions.length) root.actionIndex = actions.length - 1
    if (root.actionIndex < 0) root.actionIndex = 0
  }

  function isBackTab(event) {
    return event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))
  }

  function hexColor(color, alpha) {
    var a = alpha === undefined ? color.a : alpha
    return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + a + ")"
  }

  function hintKey(key, label) {
    return "<span style=\"color:" + root.hexColor(root.selectedText, 1) + ";\">" + key
      + "</span> <span style=\"color:" + root.hexColor(root.foreground, 0.6) + ";\">" + label + "</span>"
  }

  function hintText(items) {
    var sep = "<span style=\"color:" + root.hexColor(root.foreground, 0.4) + ";\"> · </span>"
    var parts = []
    for (var i = 0; i < items.length; i++) parts.push(root.hintKey(items[i][0], items[i][1]))
    return parts.join(sep)
  }

  function detailHintText() {
    var n = root.contextActions.length
    var items = [["enter", "copy"], ["tab ⇄", "action"], ["ctrl+f", "type"]]
    if (n > 0) items.push(["1-" + n, "pick"])
    if (root.detailVariantModes.length > 1) items.push(["v", "variant"])
    items.push(["w", "website"], ["esc", "back"])
    return root.hintText(items)
  }

  function cycleCategory(delta) {
    var cats = root.svc ? root.svc.categories : []
    if (cats.length === 0) return
    var visible = []
    for (var i = 0; i < cats.length && i < root.topCategoryCount; i++) visible.push(cats[i])
    var idx = -1
    for (i = 0; i < visible.length; i++) {
      if (visible[i].name.toLowerCase() === String(root.categoryName).toLowerCase()) { idx = i; break }
    }
    if (idx === -1) idx = delta > 0 ? -1 : visible.length
    var next = (idx + delta + visible.length) % visible.length
    root.setCategory(visible[next].name)
  }

  function select(delta) {
    if (root.visibleLogos.length === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? root.visibleLogos.length - 1 : 0
    } else {
      root.selectedIndex = (root.selectedIndex + delta + root.visibleLogos.length) % root.visibleLogos.length
    }
    logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function selectRow(delta) {
    if (root.visibleLogos.length === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? root.visibleLogos.length - 1 : 0
      logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      return
    }
    var newIndex = root.selectedIndex + delta * root.columns
    if (newIndex < 0) newIndex = 0
    if (newIndex >= root.visibleLogos.length) newIndex = root.visibleLogos.length - 1
    root.selectedIndex = newIndex
    logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function selectPage(delta) {
    if (root.visibleLogos.length === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? root.visibleLogos.length - 1 : 0
      logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      return
    }
    var visibleRows = Math.max(1, Math.floor(logosGrid.height / root.cellHeight))
    var newIndex = root.selectedIndex + delta * root.columns * visibleRows
    if (newIndex < 0) newIndex = 0
    if (newIndex >= root.visibleLogos.length) newIndex = root.visibleLogos.length - 1
    root.selectedIndex = newIndex
    logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function logoAt(index) {
    if (index < 0 || index >= root.visibleLogos.length) return null
    return root.visibleLogos[index]
  }

  function providerFor(logo) {
    if (!logo || !root.svc) return null
    for (var i = 0; i < root.svc.providers.length; i++) {
      if (root.svc.providers[i].id === logo.provider) return root.svc.providers[i]
    }
    return null
  }

  function providerFilters() {
    var out = [{ id: "all", name: "all", enabled: true, isNew: false }]
    if (root.svc) {
      for (var i = 0; i < root.svc.providers.length; i++) {
        var provider = root.svc.providers[i]
        if (!provider.enabled) continue
        out.push({ id: provider.id, name: provider.name, enabled: true, isNew: provider.isNew })
      }
    }
    return out
  }

  function providerIndexFor(id) {
    var filters = root.providerFilters()
    for (var i = 0; i < filters.length; i++) {
      if (String(filters[i].id).toLowerCase() === String(id).toLowerCase()) return i
    }
    return 0
  }

  function setProvider(id) {
    root.providerFilter = id
    root.selectedIndex = 0
    root.cursorActive = true
    if (root.svc) root.svc.setFilter(id)
    root.rebuildDisplay()
    providerChips.positionViewAtIndex(root.providerIndexFor(id), ListView.Contain)
  }

  function providerAt(id) {
    if (!root.svc) return null
    for (var i = 0; i < root.svc.providers.length; i++) {
      if (root.svc.providers[i].id === id) return root.svc.providers[i]
    }
    return null
  }

  function enableProvider(id) {
    if (id === "all" || !root.svc) return
    var provider = root.providerAt(id)
    if (!provider) return
    if (!provider.enabled) root.svc.toggleProviderEnabled(id)
    root.setProvider(id)
  }

  function disableProvider(id) {
    if (id === "all" || !root.svc) return
    var provider = root.providerAt(id)
    if (!provider || !provider.enabled) return
    root.lastDisabledId = id
    var wasActive = root.providerFilter === id
    root.svc.toggleProviderEnabled(id)
    if (wasActive) root.setProvider("all")
  }

  function toggleActiveProvider() {
    if (!root.svc) return
    if (root.providerFilter === "all") {
      var last = root.providerAt(root.lastDisabledId)
      if (last && !last.enabled) root.enableProvider(root.lastDisabledId)
      return
    }
    var provider = root.providerAt(root.providerFilter)
    if (!provider) return
    if (provider.enabled) root.disableProvider(root.providerFilter)
    else root.enableProvider(root.providerFilter)
  }

  function cycleProvider(delta) {
    var filters = root.providerFilters()
    if (filters.length === 0) return
    var step = Number(delta)
    if (!isFinite(step)) step = 1
    var next = (root.providerIndexFor(root.providerFilter) + step + filters.length) % filters.length
    root.setProvider(filters[next].id)
  }

  function activateIndex(index) {
    var logo = root.logoAt(index)
    if (!logo || !root.svc) return
    var actionId = root.activeActionId
    if (!actionId) {
      var provider = root.providerFor(logo)
      var types = Model.typesFor(provider, logo)
      var actions = types.length > 0 ? Model.actionsFor(provider, logo, types[0]) : []
      if (actions.length === 0) return
      actionId = actions[0]
    }
    root.svc.copyAction(logo, root.gridVariant(logo), actionId)
    root.dismiss()
  }

  function openDetail(index) {
    var logo = root.logoAt(index)
    if (!logo) return
    root.detail = logo
    root.variantIndex = 0
    if (root.svc) root.svc.ensureLogo(logo, root.detailVariant)
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function copyDetail() {
    if (!root.detail || !root.svc) return
    var actionId = root.activeActionId
    if (!actionId) return
    root.svc.copyAction(root.detail, root.detailVariant, actionId)
    root.dismiss()
  }

  function gridVariant(logo) {
    return Model.resolveVariant(logo, root.preferDark, Model.primaryKind(logo))
  }

  function cycleVariant(delta) {
    if (!root.detail) return
    var modes = Model.variantModes(root.detail, root.currentType())
    if (modes.length < 2) return
    var step = Number(delta) || 1
    root.variantIndex = (root.variantIndex + step + modes.length) % modes.length
    var v = modes[Math.max(0, Math.min(root.variantIndex, modes.length - 1))]
    if (root.svc) root.svc.ensureLogo(root.detail, v)
  }

  function commandModel() {
    return [
      { id: "providers",    name: "providers — enable/disable", shortcut: "ctrl+t", run: function() { root.openProviderPicker() } },
      { id: "categories",   name: "categories — browse all",    shortcut: "ctrl+k", run: function() { root.openCategoryPicker() } },
      { id: "refresh",      name: "refresh catalogs",           shortcut: "ctrl+r", run: function() { root.refresh() } },
      { id: "clear",        name: "clear local cache",          shortcut: "",       run: function() { root.clearCache() } },
      { id: "cycleprovider", name: "cycle provider",            shortcut: "ctrl+tab", run: function() { root.cycleProvider(1) } },
      { id: "copy",         name: "copy active item",           shortcut: "ctrl+c", run: function() { if (root.detail) root.copyDetail(); else root.activateIndex(root.selectedIndex) } },
      { id: "format",       name: "cycle format (svg/png/webp)", shortcut: "ctrl+f", run: function() { root.cycleType(1) } },
      { id: "variant",      name: "toggle color variant",       shortcut: "v",       run: function() { root.cycleVariant(1) } },
      { id: "website",      name: "open website",               shortcut: "w",       run: function() { root.openDetailSite() } },
      { id: "close",        name: "close overlay",              shortcut: "esc",     run: function() { root.dismiss() } }
    ]
  }

  readonly property var commandPickModel: (function() {
    var needle = root.commandSearch.trim().toLowerCase()
    var all = root.commandModel()
    if (!needle) return all
    var out = []
    for (var i = 0; i < all.length; i++) {
      if (all[i].name.toLowerCase().indexOf(needle) !== -1) out.push(all[i])
    }
    return out
  })()

  function openCommandPalette() {
    root.commandPalette = true
    root.commandSearch = ""
    root.commandPickIndex = 0
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function closeCommandPalette() {
    root.commandPalette = false
    root.commandSearch = ""
  }

  function moveCommandPick(delta) {
    var model = root.commandPickModel
    if (!model || model.length === 0) return
    root.commandPickIndex = (root.commandPickIndex + delta + model.length) % model.length
    commandPickList.positionViewAtIndex(root.commandPickIndex, ListView.Contain)
  }

  function runCommandAt(index) {
    var model = root.commandPickModel
    if (!model || index < 0 || index >= model.length) return
    var cmd = model[index]
    root.commandPalette = false
    root.commandSearch = ""
    try {
      cmd.run()
    } catch (e) {
      console.warn("command threw:", e)
    }
  }

  function openDetailSite() {
    if (!root.detail || !root.svc || !root.detail.url) return
    root.svc.openUrl(root.detail.url)
  }

  function logoKey(logo, variant) {
    if (!logo) return ""
    return Model.logoCacheKey(logo, variant)
  }

  function logoSource(logo, variant) {
    if (!logo || !root.svc) return ""
    var revision = root.svc.readyRevision
    var key = root.logoKey(logo, variant)
    var state = root.svc.ready[key]
    if (!state) return ""
    if (Model.primaryKind(logo) === "png")
      return Util.fileUrl(root.svc.libraryDir + "/" + key + ".png")
    return Util.fileUrl(root.svc.libraryDir + "/" + key + (state === "png" ? ".svg.png" : ".svg"))
  }

  onSvcChanged: root.rebuildDisplay()
  onPreferDarkChanged: {
    if (root.svc) {
      root.svc.preferDark = root.preferDark
      root.svc.prefetch()
    }
    root.rebuildDisplay()
  }
  onSelectedIndexChanged: { root.syncSelection(); root.clampAction() }
  onDetailChanged: { root.syncSelection(); root.clampAction() }
  onCategorySearchChanged: root.categoryPickIndex = 0

  property Timer filterTimer: Timer {
    interval: 70
    repeat: false
    onTriggered: root.rebuildDisplay()
  }

  Connections {
    target: root.svc
    function onLogosChanged() { root.rebuildDisplay() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "ussego-omiru"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.commandPalette) {
            if (event.key === Qt.Key_Escape) {
              root.closeCommandPalette()
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.runCommandAt(root.commandPickIndex)
            } else if (event.key === Qt.Key_Up) {
              root.moveCommandPick(-1)
            } else if (event.key === Qt.Key_Down) {
              root.moveCommandPick(1)
            } else if (event.key === Qt.Key_Backspace) {
              root.commandSearch = root.commandSearch.slice(0, -1)
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
              root.commandSearch += event.text
            }
            event.accepted = true
            return
          }
          if (root.providerPicker) {
            if (event.key === Qt.Key_Escape) {
              root.closeProviderPicker()
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                       || (event.key === Qt.Key_Space && event.modifiers === Qt.NoModifier)) {
              root.flipProviderPickAt(root.providerPickIndex)
            } else if (event.key === Qt.Key_Up) {
              root.moveProviderPick(-1)
            } else if (event.key === Qt.Key_Down) {
              root.moveProviderPick(1)
            }
            event.accepted = true
            return
          }
          if (root.categoryPicker) {
            if (event.key === Qt.Key_Escape) {
              root.closeCategoryPicker()
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.pickCategoryAt(root.categoryPickIndex)
            } else if (event.key === Qt.Key_Up) {
              root.moveCategoryPick(-1)
            } else if (event.key === Qt.Key_Down) {
              root.moveCategoryPick(1)
            } else if (event.key === Qt.Key_Backspace) {
              root.categorySearch = root.categorySearch.slice(0, -1)
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
              root.categorySearch += event.text
            }
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape) {
            if (root.detail) root.detail = null
            else if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_F && event.modifiers === Qt.ControlModifier) {
            root.cycleType(1)
            event.accepted = true
          } else if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
            if (root.detail) root.copyDetail()
            else root.activateIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_P && event.modifiers === Qt.ControlModifier) {
            root.openCommandPalette()
            event.accepted = true
          } else if (event.key === Qt.Key_T && event.modifiers === Qt.ControlModifier) {
            root.openProviderPicker()
            event.accepted = true
          } else if (root.detail) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.copyDetail()
              event.accepted = true
            } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.ControlModifier)) {
              root.cycleProvider(root.isBackTab(event) ? -1 : 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              root.cycleAction(root.isBackTab(event) ? -1 : 1)
              event.accepted = true
            } else if (event.text === "w" || event.text === "W") {
              root.openDetailSite()
              event.accepted = true
            } else if (event.key === Qt.Key_Delete) {
              root.toggleActiveProvider()
              event.accepted = true
            } else if ((event.text === "v" || event.text === "V") && root.detailVariantModes.length > 1) {
              root.cycleVariant(1)
              event.accepted = true
            } else if (event.text.length === 1) {
              var nActions = root.contextActions.length
              var code = event.text.charCodeAt(0)
              if (nActions > 0 && code >= 49 && code <= 48 + nActions) {
                root.pickAction(code - 48)
                event.accepted = true
              }
            }
          } else if (event.key === Qt.Key_Delete) {
            root.toggleActiveProvider()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && event.modifiers & Qt.ControlModifier) {
            root.cycleProvider(root.isBackTab(event) ? -1 : 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.cycleCategory(root.isBackTab(event) ? -1 : 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.selectRow(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.selectRow(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.openDetail(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_K && event.modifiers === Qt.ControlModifier) {
            root.openCategoryPicker()
            event.accepted = true
          } else if (event.key === Qt.Key_P && event.modifiers === Qt.ControlModifier) {
            root.openCommandPalette()
            event.accepted = true
          } else if (event.key === Qt.Key_T && event.modifiers === Qt.ControlModifier) {
            root.openProviderPicker()
            event.accepted = true
          } else if (event.key === Qt.Key_R && event.modifiers === Qt.ControlModifier) {
            root.refresh()
            event.accepted = true
          } else if (event.key === Qt.Key_D && event.modifiers === Qt.ControlModifier) {
            root.openDetail(root.selectedIndex)
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Text {
            anchors.left: parent.left
            anchors.right: headerStatus.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || "Search icons…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Row {
            id: headerStatus
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(14)

            Text {
              visible: root.svc ? root.svc.indexing : false
              height: Style.space(26)
              verticalAlignment: Text.AlignVCenter
              text: "Indexing " + Math.min(99, Math.round((root.svc ? root.svc.indexProgress : 0) * 100)) + "%"
              color: root.foreground
              opacity: 0.35
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              height: Style.space(26)
              verticalAlignment: Text.AlignVCenter
              text: (root.svc && root.svc.status === "loading" ? "󰑓 " : "")
                + root.visibleLogos.length + " / " + (root.svc ? root.svc.logos.length : 0)
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Rectangle {
              visible: root.activeActionLabel !== ""
              height: Style.space(26)
              radius: root.cornerRadius
              color: root.selectedBackground
              width: headerActionMeasure.implicitWidth + Style.space(16)

              Text {
                id: headerActionMeasure
                visible: false
                text: "WebP URL"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                id: headerActionLabel
                anchors.centerIn: parent
                text: root.activeActionLabel
                color: root.selectedText
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                width: headerActionMeasure.implicitWidth
              }
            }
          }
        }

        ListView {
          id: providerChips
          width: parent.width
          height: root.providersHeight
          orientation: ListView.Horizontal
          model: root.providerFilters()
          clip: true
          spacing: Style.space(6)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property int index
            required property var modelData

            readonly property bool active: modelData.id === root.providerFilter

            width: providerChipRow.implicitWidth + Style.space(20)
            height: root.providersHeight
            radius: root.cornerRadius
            color: active ? root.selectedBackground : "transparent"

            Row {
              id: providerChipRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                id: providerLabel
                text: modelData.name
                color: active ? root.selectedText : root.foreground
                opacity: active ? 1 : 0.7
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: active
              }

              Rectangle {
                visible: modelData.isNew
                height: Style.space(13)
                radius: Style.space(7)
                anchors.verticalCenter: parent.verticalCenter
                color: root.hexColor(Color.urgent, 0.18)
                width: newPillLabel.implicitWidth + Style.space(8)

                Text {
                  id: newPillLabel
                  anchors.centerIn: parent
                  text: "NEW"
                  color: Color.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Math.max(7, Math.round(Style.font.caption * 0.62))
                  font.bold: true
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (modelData.id === "all") {
                  root.setProvider("all")
                } else if (mouse.button === Qt.RightButton) {
                  root.disableProvider(modelData.id)
                } else {
                  root.setProvider(modelData.id)
                }
              }
            }
          }
        }

        ListView {
          id: chipsList
          width: parent.width
          height: root.chipsHeight
          orientation: ListView.Horizontal
          model: root.categoryRowModel
          clip: true
          spacing: Style.space(6)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property int index
            required property var modelData

            readonly property bool isMore: Boolean(modelData.more)
            readonly property bool active: isMore ? root.categoryPicker : modelData.name === root.categoryName

            width: chipLabel.implicitWidth + Style.space(20)
            height: root.chipsHeight
            radius: root.cornerRadius
            color: active ? root.selectedBackground : "transparent"

            Text {
              id: chipLabel
              anchors.centerIn: parent
              text: isMore ? "…" : (modelData.name + " " + modelData.total)
              color: active ? root.selectedText : root.foreground
              opacity: active ? 1 : 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: isMore ? root.openCategoryPicker() : root.setCategory(modelData.name)
            }
          }
        }

        Item {
          id: contentArea
          width: parent.width
          height: parent.height - root.headerHeight - root.providersHeight - root.chipsHeight - root.contentSpacing * 3

          GridView {
            id: logosGrid
            visible: root.detail === null
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: gridHint.top
            anchors.bottomMargin: Style.space(6)
            model: root.visibleLogos
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            cacheBuffer: root.cellHeight * 2
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property int index

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
              readonly property var logo: root.logoAt(index)
              readonly property string gridVariant: root.gridVariant(logo)
              readonly property string logoKey: root.logoKey(logo, gridVariant)
              readonly property bool logoReady: root.svc !== null && (root.svc.readyRevision, Boolean(root.svc.ready[logoKey]))

              width: root.cellWidth
              height: root.cellHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Component.onCompleted: if (root.svc && logo) root.svc.ensureLogo(logo, gridVariant)

              Image {
                id: logoImage
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(10)
                width: Style.space(40)
                height: Style.space(40)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 128
                source: root.logoSource(logo, gridVariant)
              }

              Text {
                visible: !logoReady
                anchors.centerIn: logoImage
                text: "󰋩"
                color: hasCursor ? root.selectedText : root.foreground
                opacity: 0.25
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }

              Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: logoImage.bottom
                anchors.topMargin: Style.space(6)
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                text: logo ? logo.title : ""
                color: hasCursor ? root.selectedText : root.foreground
                opacity: 0.75
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Rectangle {
                visible: root.showProviderBadges
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(3)
                width: badgeText.implicitWidth + Style.space(8)
                height: badgeText.implicitHeight + Style.space(3)
                radius: Math.round(height / 2)
                color: hasCursor ? root.selectedBackground : root.background

                Text {
                  id: badgeText
                  anchors.centerIn: parent
                  text: (function() {
                    var p = root.providerFor(logo)
                    return p && p.def ? p.def.shortName : ""
                  })()
                  color: hasCursor ? root.selectedText : root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Math.max(7, Math.round(Style.font.caption * 0.62))
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) {
                  root.cursorActive = true
                  root.selectedIndex = index
                }
                onClicked: function(mouse) {
                  root.cursorActive = true
                  root.selectedIndex = index
                  if (mouse.button === Qt.RightButton) root.activateIndex(index)
                  else root.openDetail(index)
                }
              }
            }
          }

          Text {
            id: gridHint
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: root.detail
              ? root.detailHintText()
              : root.hintText([["ctrl+p", "menu"], ["ctrl+c", "copy"], ["enter", "details"], ["tab ⇄", "category"], ["ctrl+k", "categories"], ["ctrl+tab ⇄", "provider"], ["ctrl+t", "providers"], ["esc", "close"]])
            color: root.foreground
            textFormat: Text.RichText
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          Item {
            id: detailView
            visible: root.detail !== null
            anchors.fill: parent

            Column {
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              spacing: root.contentSpacing

              Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(96)
                height: Style.space(96)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                sourceSize.width: 192
                sourceSize.height: 192
                source: root.logoSource(root.detail, root.detailVariant)
              }

              Text {
                visible: root.detail !== null && !(root.svc && (root.svc.readyRevision, root.svc.ready[root.logoKey(root.detail, root.detailVariant)]))
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰋩"
                color: root.foreground
                opacity: 0.25
                font.family: root.fontFamily
                font.pixelSize: Style.font.displayLarge
              }

              Text {
                width: parent.width
                text: root.detail ? root.detail.title : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.detail ? ((root.providerFor(root.detail) ? root.providerFor(root.detail).name + " · " : "")
                  + (Model.sourceLabel(root.detail) ? Model.sourceLabel(root.detail) + " · " : "")
                  + root.detail.categories.join(" · ")) : ""
                color: root.foreground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.detail ? root.detail.url : ""
                color: root.selectedText
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Text {
                visible: root.detail !== null && root.detail.brandUrl && root.detail.brandUrl !== root.detail.url
                width: parent.width
                text: root.detail ? root.detail.brandUrl : ""
                color: root.foreground
                opacity: 0.5
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Item {
                width: parent.width
                height: Style.space(6)
              }

              Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(8)
                visible: root.contextTypes.length > 0

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(6)

                  Repeater {
                    model: root.contextTypes

                    delegate: Rectangle {
                      required property int index
                      required property string modelData

                      readonly property bool active: index === root.typeIndex

                      width: typeChipText.implicitWidth + Style.space(20)
                      height: Style.space(30)
                      radius: root.cornerRadius
                      color: active ? root.selectedBackground : "transparent"

                      Text {
                        id: typeChipText
                        anchors.centerIn: parent
                        text: modelData
                        color: active ? root.selectedText : root.foreground
                        opacity: active ? 1 : 0.6
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.typeIndex = index
                          root.actionIndex = 0
                        }
                      }
                    }
                  }
                }

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(18)

                  Text {
                    height: Style.space(30)
                    verticalAlignment: Text.AlignVCenter
                    text: "copy as"
                    color: root.foreground
                    opacity: 0.5
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Repeater {
                    model: root.contextActions

                    delegate: Item {
                      required property int index
                      required property string modelData

                      readonly property bool active: modelData === root.activeActionId

                      height: Style.space(30)
                      width: actionText.implicitWidth

                      Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: (index + 1) + " " + Model.actionLabel(modelData)
                        color: active ? root.selectedText : root.foreground
                        opacity: active ? 1 : 0.6
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: active
                        font.letterSpacing: 0
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.pickAction(index + 1); root.copyDetail() }
                      }
                    }
                  }
                }
              }

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(6)

                Repeater {
                  model: root.detailVariantModes

                  delegate: Item {
                    required property int index
                    required property string modelData

                    readonly property bool active: index === Math.max(0, Math.min(root.variantIndex, root.detailVariantModes.length - 1))

                    height: Style.space(22)
                    width: variantLabel.implicitWidth + Style.space(20)

                    Text {
                      id: variantLabel
                      anchors.centerIn: parent
                      text: (active ? "● " : "○ ") + modelData
                      color: active ? root.selectedText : root.foreground
                      opacity: active ? 1 : 0.55
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: active
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.variantIndex = index
                        if (root.svc && root.detail) {
                          var modes = Model.variantModes(root.detail, root.currentType())
                          var v = modes[Math.max(0, Math.min(index, modes.length - 1))]
                          root.svc.ensureLogo(root.detail, v)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: root.visibleLogos.length === 0 && root.detail === null

            Text {
              visible: !root.catalogLoading && !root.catalogError
              text: "󰈉"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              text: root.stateMessage
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }

          Rectangle {
            id: commandPalettePanel
            visible: root.commandPalette
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.dialogVerticalOffset
            width: Math.min(Style.space(360), (contentArea ? contentArea.width : 0) - Style.space(16))
            height: Math.min(Style.space(400), (contentArea ? contentArea.height : 0) - Style.space(16))
            radius: root.cornerRadius
            color: root.background
            border.color: root.border
            border.width: Math.max(1, Style.space(2))

            Item {
              anchors.fill: parent
              anchors.margins: Style.space(12)

              Text {
                id: commandSearchText
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.commandSearch ? root.commandSearch : "commands…"
                color: root.foreground
                opacity: root.commandSearch ? 1 : 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                elide: Text.ElideRight
              }

              ListView {
                id: commandPickList
                anchors.top: commandSearchText.bottom
                anchors.topMargin: Style.space(8)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                model: root.commandPickModel
                boundsBehavior: Flickable.StopAtBounds
                spacing: Style.space(2)

                delegate: Rectangle {
                  required property int index
                  required property var modelData

                  width: parent ? parent.width : 0
                  height: Style.space(32)
                  radius: root.cornerRadius
                  color: index === root.commandPickIndex ? root.selectedBackground : "transparent"

                  Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    text: modelData.name
                    color: index === root.commandPickIndex ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Style.space(8)
                    text: modelData.shortcut
                    visible: modelData.shortcut !== ""
                    color: index === root.commandPickIndex ? root.selectedText : root.foreground
                    opacity: 0.45
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) root.commandPickIndex = index
                    onClicked: root.runCommandAt(index)
                  }
                }
              }
            }
          }

          Rectangle {
            id: providerPickerPanel
            visible: root.providerPicker
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.dialogVerticalOffset
            width: Math.min(Style.space(320), (contentArea ? contentArea.width : 0) - Style.space(16))
            height: Math.min(Style.space(360), (contentArea ? contentArea.height : 0) - Style.space(16))
            radius: root.cornerRadius
            color: root.background
            border.color: root.border
            border.width: Math.max(1, Style.space(2))

            Item {
              anchors.fill: parent
              anchors.margins: Style.space(12)

              Text {
                id: providerPickerTitle
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: "providers — enter/space toggle · esc close"
                color: root.foreground
                opacity: 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              ListView {
                id: providerPickList
                anchors.top: providerPickerTitle.bottom
                anchors.topMargin: Style.space(8)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                model: root.providerPickModel
                boundsBehavior: Flickable.StopAtBounds
                spacing: Style.space(2)

                delegate: Rectangle {
                  required property int index
                  required property var modelData

                  readonly property bool selected: index === root.providerPickIndex

                  width: parent ? parent.width : 0
                  height: Style.space(32)
                  radius: root.cornerRadius
                  color: selected ? root.selectedBackground : "transparent"

                  Item {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)

                    Text {
                      id: rowDotText
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.enabled ? "●" : "○"
                      color: modelData.enabled ? root.selectedText : root.foreground
                      opacity: modelData.enabled ? 1 : 0.5
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: modelData.enabled
                      width: Style.space(14)
                      horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                      id: rowNewPill
                      visible: modelData.isNew
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      height: Style.space(13)
                      radius: Style.space(7)
                      color: root.hexColor(Color.urgent, 0.18)
                      width: rowNewPillLabel.implicitWidth + Style.space(8)

                      Text {
                        id: rowNewPillLabel
                        anchors.centerIn: parent
                        text: "NEW"
                        color: Color.urgent
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(7, Math.round(Style.font.caption * 0.62))
                        font.bold: true
                      }
                    }

                    Text {
                      anchors.left: rowDotText.right
                      anchors.right: rowNewPill.visible ? rowNewPill.left : parent.right
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name
                      color: selected ? root.selectedText : root.foreground
                      opacity: modelData.enabled ? 1 : 0.5
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) root.providerPickIndex = index
                    onClicked: root.flipProviderPickAt(index)
                  }
                }
              }
            }
          }

          Rectangle {
            id: categoryPickerPanel
            visible: root.categoryPicker
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.dialogVerticalOffset
            width: Math.min(Style.space(320), (contentArea ? contentArea.width : 0) - Style.space(16))
            height: Math.min(Style.space(360), (contentArea ? contentArea.height : 0) - Style.space(16))
            radius: root.cornerRadius
            color: root.background
            border.color: root.border
            border.width: Math.max(1, Style.space(2))

            Item {
              anchors.fill: parent
              anchors.margins: Style.space(12)

              Text {
                id: pickerSearchText
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.categorySearch ? root.categorySearch : "filter categories…"
                color: root.foreground
                opacity: root.categorySearch ? 1 : 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                elide: Text.ElideRight
              }

              ListView {
                id: categoryPickList
                anchors.top: pickerSearchText.bottom
                anchors.topMargin: Style.space(8)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                model: root.categoryPickModel
                boundsBehavior: Flickable.StopAtBounds
                spacing: Style.space(2)

                delegate: Rectangle {
                  required property int index
                  required property var modelData

                  width: parent ? parent.width : 0
                  height: Style.space(32)
                  radius: root.cornerRadius
                  color: index === root.categoryPickIndex ? root.selectedBackground : "transparent"

                  Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    text: modelData.name + "  " + modelData.total
                    color: index === root.categoryPickIndex ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse && !root.categorySearch) root.categoryPickIndex = index
                    onClicked: root.pickCategoryAt(index)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
