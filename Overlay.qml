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
  property string categoryName: "All"
  property int formatIndex: 0
  property var detail: null
  property var visibleLogos: []

  readonly property string copyFormat: Model.FORMATS[Math.max(0, Math.min(Model.FORMATS.length - 1, root.formatIndex))]

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
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(760), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(560), panel.height - Style.gapsOut * 2)
  property int minCellWidth: Style.space(104)
  property int cellHeight: Style.space(88)

  readonly property bool preferDark: Model.isDark(root.background)
  readonly property int columns: Math.max(1, Math.floor(contentArea.width / root.minCellWidth))
  readonly property int cellWidth: Math.max(root.minCellWidth, Math.floor(contentArea.width / root.columns))
  readonly property bool catalogLoading: root.svc === null || (root.svc.status === "loading" && root.svc.logos.length === 0)
  readonly property bool catalogError: root.svc !== null && root.svc.status === "error" && root.svc.logos.length === 0
  readonly property string stateMessage: root.catalogLoading
    ? "Loading logos from svgl.app…"
    : root.catalogError
      ? (root.svc.message || "Couldn't reach svgl.app")
      : "No matches for “" + root.filterText + "”"

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    root.opened = true
    root.filterText = typeof payload.query === "string" ? payload.query : ""
    root.categoryName = typeof payload.category === "string" && payload.category ? payload.category : "All"
    root.detail = null
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
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
    var logos = root.svc ? root.svc.logos : []
    var out = Model.filterLogos(logos, root.filterText, root.categoryName, 800)
    root.visibleLogos = out

    displayModel.clear()
    for (var j = 0; j < out.length; j++) displayModel.append({ title: out[j].title })

    if (displayModel.count === 0) root.selectedIndex = 0
    else if (root.selectedIndex >= displayModel.count) root.selectedIndex = displayModel.count - 1
    else if (root.selectedIndex < 0) root.selectedIndex = 0
    root.cursorActive = displayModel.count > 0

    Qt.callLater(function() {
      if (displayModel.count > 0) logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
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

  function cycleFormat(delta) {
    var count = Model.FORMATS.length
    var step = Number(delta)
    if (!isFinite(step)) step = 1
    root.formatIndex = (root.formatIndex + step + count * 100) % count
  }

  function pickFormat(number) {
    if (number >= 1 && number <= Model.FORMATS.length) root.formatIndex = number - 1
  }

  function cycleCategory(delta) {
    var cats = root.svc ? root.svc.categories : []
    if (cats.length === 0) return
    var next = (root.categoryIndexFor(root.categoryName) + delta + cats.length) % cats.length
    root.setCategory(cats[next].name)
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      root.selectedIndex = (root.selectedIndex + delta + displayModel.count) % displayModel.count
    }
    logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function selectRow(delta) {
    if (displayModel.count === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? displayModel.count - 1 : 0
      logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      return
    }
    var newIndex = root.selectedIndex + delta * root.columns
    if (newIndex < 0) newIndex = 0
    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1
    root.selectedIndex = newIndex
    logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function selectPage(delta) {
    if (displayModel.count === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? displayModel.count - 1 : 0
      logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      return
    }
    var visibleRows = Math.max(1, Math.floor(logosGrid.height / root.cellHeight))
    var newIndex = root.selectedIndex + delta * root.columns * visibleRows
    if (newIndex < 0) newIndex = 0
    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1
    root.selectedIndex = newIndex
    logosGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function logoAt(index) {
    if (index < 0 || index >= root.visibleLogos.length) return null
    return root.visibleLogos[index]
  }

  function activateIndex(index) {
    var logo = root.logoAt(index)
    if (!logo || !root.svc) return
    root.svc.copyFormatted(logo, root.preferDark, root.copyFormat)
    root.dismiss()
  }

  function openDetail(index) {
    var logo = root.logoAt(index)
    if (!logo) return
    root.detail = logo
    if (root.svc) root.svc.ensureLogo(logo, root.preferDark)
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function copyDetail() {
    if (!root.detail || !root.svc) return
    root.svc.copyFormatted(root.detail, root.preferDark, root.copyFormat)
    root.dismiss()
  }

  function openDetailSite() {
    if (!root.detail || !root.svc || !root.detail.url) return
    root.svc.openUrl(root.detail.url)
  }

  function detailSlug(logo) {
    if (!logo) return ""
    return Model.slugFor(Model.routeUrl(logo.route, root.preferDark), logo.id)
  }

  function logoSource(logo) {
    if (!logo || !root.svc) return ""
    var slug = root.detailSlug(logo)
    var state = root.svc.ready[slug]
    if (!state) return ""
    return Util.fileUrl(root.svc.libraryDir + "/" + slug + (state === "png" ? ".png" : ""))
  }

  onSvcChanged: root.rebuildDisplay()
  onPreferDarkChanged: root.rebuildDisplay()

  ListModel { id: displayModel }

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
          if (event.key === Qt.Key_Escape) {
            if (root.detail) root.detail = null
            else if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_F && event.modifiers === Qt.ControlModifier) {
            root.cycleFormat(1)
            event.accepted = true
          } else if (root.detail) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.copyDetail()
              event.accepted = true
            } else if (event.text === "w" || event.text === "W") {
              root.openDetailSite()
              event.accepted = true
            } else if (event.text.length === 1 && event.text.charCodeAt(0) >= 49 && event.text.charCodeAt(0) <= 48 + Model.FORMATS.length) {
              root.pickFormat(event.text.charCodeAt(0) - 48)
              event.accepted = true
            }
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.cycleCategory(event.key === Qt.Key_Backtab ? -1 : 1)
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
            root.activateIndex(root.selectedIndex)
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
            text: root.filterText || "Search svgl logos…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: headerStatus
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (root.svc && root.svc.status === "loading" ? "󰑓 " : "")
              + root.copyFormat + " · " + root.visibleLogos.length + " / " + (root.svc ? root.svc.logos.length : 0)
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        ListView {
          id: chipsList
          width: parent.width
          height: root.chipsHeight
          orientation: ListView.Horizontal
          model: root.svc ? root.svc.categories : []
          clip: true
          spacing: Style.space(6)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property int index
            required property var modelData

            readonly property bool active: modelData.name === root.categoryName

            width: chipLabel.implicitWidth + Style.space(20)
            height: root.chipsHeight
            radius: root.cornerRadius
            color: active ? root.selectedBackground : "transparent"

            Text {
              id: chipLabel
              anchors.centerIn: parent
              text: modelData.name + " " + modelData.total
              color: active ? root.selectedText : root.foreground
              opacity: active ? 1 : 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setCategory(modelData.name)
            }
          }
        }

        Item {
          id: contentArea
          width: parent.width
          height: parent.height - root.headerHeight - root.chipsHeight - root.contentSpacing * 2

          GridView {
            id: logosGrid
            visible: root.detail === null
            anchors.fill: parent
            model: displayModel
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property int index
              required property string title

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
              readonly property var logo: root.logoAt(index)
              readonly property string logoSlug: root.detailSlug(logo)
              readonly property bool logoReady: root.svc !== null && Boolean(root.svc.ready[logoSlug])

              width: root.cellWidth
              height: root.cellHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Component.onCompleted: if (root.svc && logo) root.svc.ensureLogo(logo, root.preferDark)

              Image {
                id: logoImage
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(10)
                width: Style.space(40)
                height: Style.space(40)
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: root.logoSource(logo)
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
                text: title
                color: hasCursor ? root.selectedText : root.foreground
                opacity: 0.75
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
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
                  if (mouse.button === Qt.RightButton) root.openDetail(index)
                  else root.activateIndex(index)
                }
              }
            }
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
                source: root.logoSource(root.detail)
              }

              Text {
                visible: root.detail !== null && !(root.svc && root.svc.ready[root.detailSlug(root.detail)])
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
                text: root.detail ? root.detail.categories.join(" · ") : ""
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

              Text {
                width: parent.width
                text: "enter copy " + root.copyFormat + " · ctrl+f or 1-" + Model.FORMATS.length + " format · w website · esc back"
                color: root.foreground
                opacity: 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0 && root.detail === null

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
        }
      }
    }
  }
}
