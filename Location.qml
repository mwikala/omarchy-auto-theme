import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Column {
  id: root

  property string location: ""
  property string place: ""
  property string source: "ip"
  property bool locating: false
  property color foreground: Commons.Color.foreground
  property color dim: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool editing: false
  property string query: ""
  property string error: ""
  property var suggestions: []
  property int highlighted: 0
  property string pendingQuery: ""
  property string activeQuery: ""
  property int revision: 0
  property int activeRevision: -1
  readonly property bool manual: editing || source === "manual"
  readonly property string io: decodeURIComponent(Qt.resolvedUrl("bin/omarchy-auto-theme-io").toString().replace(/^file:\/\//, ""))

  signal save(string coordinates, string name)
  signal automatic()

  spacing: Style.spacing.md
  onVisibleChanged: if (!visible) reset()

  function reset() {
    revision++
    editing = false
    error = ""
    suggestions = []
    search.stop()
    query = source === "manual" ? place : ""
  }

  function edit() {
    if (!editing) query = source === "manual" ? place : ""
    editing = true
    error = ""
    if (editor.item) {
      editor.item.selectAll()
      editor.item.forceActiveFocus()
    }
  }

  function lookup() {
    var city = query.trim()
    if (!editing || city.length < 2 || coordinates(city)) {
      suggestions = []
      return
    }
    pendingQuery = city
    if (!geocoder.running) startLookup()
  }

  function startLookup() {
    if (!editing || pendingQuery.length < 2 || pendingQuery !== query.trim()) return
    activeRevision = revision
    activeQuery = pendingQuery
    geocoder.command = [io, "city", activeQuery]
    geocoder.running = true
  }

  function pick(suggestion) {
    if (!suggestion) return
    revision++
    editing = false
    search.stop()
    error = ""
    suggestions = []
    query = suggestion.name
    save(suggestion.latitude + " " + suggestion.longitude, suggestion.name)
  }

  // Enter takes the highlighted city. Coordinates still work for anyone who
  // pastes them, without being something the UI asks for.
  function commit() {
    var position = coordinates(query)
    if (position) {
      revision++
      editing = false
      search.stop()
      save(position, "")
      return
    }
    if (suggestions.length > 0) {
      pick(suggestions[highlighted])
      return
    }
    if (search.running || geocoder.running) return
    error = query.trim() === "" ? "Type a town or city" : "No places found. Try a nearby town."
  }

  function coordinates(text) {
    var pair = text.trim().replace(/,/g, " ").split(/\s+/)
    if (pair.length === 2 && pair.every(function(part) { return /^-?\d+(\.\d+)?$/.test(part) })
        && Math.abs(Number(pair[0])) <= 90 && Math.abs(Number(pair[1])) <= 180) {
      return pair.join(" ")
    }
    return ""
  }

  function results(raw) {
    if (raw.length > 32768) return []
    try {
      var places = JSON.parse(raw).results
      if (!Array.isArray(places)) return []
      return places.slice(0, 5).filter(function(entry) {
        if (!entry || !label(entry.name)) return false
        if (entry.admin1 !== undefined && !label(entry.admin1)) return false
        if (entry.country !== undefined && !label(entry.country)) return false
        return typeof entry.name === "string" && typeof entry.latitude === "number" && typeof entry.longitude === "number"
          && isFinite(entry.latitude) && isFinite(entry.longitude)
          && Math.abs(entry.latitude) <= 90 && Math.abs(entry.longitude) <= 180
      }).map(function(entry) {
        return {
          name: String(entry.name),
          region: [entry.admin1, entry.country].filter(function(part) { return !!part }).join(", "),
          latitude: entry.latitude,
          longitude: entry.longitude
        }
      })
    } catch (e) {
      return []
    }
  }

  function label(text) {
    return typeof text === "string" && text.length > 0 && text.length <= 128
      && !/["\u0000-\u001f\u007f-\u009f]/.test(text)
  }

  function paste(primary) {
    if (!editing || !visible || !editor.item || clipboard.running) return
    clipboard.revision = revision
    clipboard.command = primary ? [io, "clipboard", "primary"] : [io, "clipboard"]
    clipboard.running = true
  }

  Process {
    id: clipboard
    property int revision: -1
    stdout: StdioCollector { id: pasted; waitForEnd: true }
    onExited: function(code) {
      if (!root.editing || !root.visible || !editor.item || !editor.item.activeFocus || revision !== root.revision) return
      if (code !== 0) { root.error = "Couldn't paste. Use a short city name or coordinates."; return }
      try {
        if (!editor.item.replace(JSON.parse(pasted.text))) root.error = "Use at most 128 characters on one line."
      } catch (e) { root.error = "Couldn't read clipboard text." }
    }
  }

  Process {
    id: geocoder
    stdout: StdioCollector { id: response; waitForEnd: true }
    onExited: function(code) {
      Qt.callLater(function() {
        if (!root.editing) return
        if (root.activeRevision !== root.revision || root.activeQuery !== root.query.trim()) {
          if (!search.running) root.lookup()
          return
        }
        root.suggestions = code === 0 ? root.results(response.text) : []
        root.highlighted = 0
        root.error = code !== 0 ? "City search is unavailable. Try again when you're online."
          : root.suggestions.length === 0 ? "No places found. Try a nearby town." : ""
      })
    }
  }

  Timer {
    id: search
    interval: 300
    onTriggered: root.lookup()
  }

  Segments {
    width: parent.width
    caption: "Location"
    options: [
      { value: "auto", label: "Automatic" },
      { value: "manual", label: "Manual" }
    ]
    value: root.manual ? "manual" : "auto"
    foreground: root.foreground
    fontFamily: root.fontFamily
    onSelected: function(value) {
      if (value === "manual") { root.edit(); return }
      root.reset()
      if (root.source !== "ip") root.automatic()
    }
  }

  Text {
    visible: !root.manual
    width: parent.width
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    text: root.locating ? "Finding your location…"
      : root.location === "" ? "Couldn't find your location. Choose Manual to search for it."
      : (root.place || "Your area") + " · approximate, from your internet connection"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Loader {
    id: editor
    active: root.visible && root.editing
    visible: active
    width: parent.width
    onLoaded: {
      item.selectAll()
      item.forceActiveFocus()
    }

    sourceComponent: Entry {
      text: root.query
      placeholderText: "Search city"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      topPadding: Style.spacing.inputPaddingY + frame.borderTop
      bottomPadding: Style.spacing.inputPaddingY + frame.borderBottom
      leftPadding: Style.spacing.controlPaddingX + frame.borderLeft
      rightPadding: Style.spacing.controlPaddingX + frame.borderRight
      selectionColor: Style.selectionFillFor(root.foreground, Commons.Color.accent)
      selectedTextColor: root.foreground
      Accessible.name: "Search for your town or city"
      onPasteRequested: function(primary) { root.paste(primary) }
      onEdited: {
        root.query = text
        root.revision++
        root.suggestions = []
        root.highlighted = 0
        root.error = ""
        search.restart()
      }
      onNavigated: function(key) {
        if (key === Qt.Key_Down) {
          root.highlighted = Math.max(0, Math.min(root.highlighted + 1, root.suggestions.length - 1))
        } else if (key === Qt.Key_Up) {
          root.highlighted = Math.max(root.highlighted - 1, 0)
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
          root.commit()
        } else if (key === Qt.Key_Escape && root.editing) {
          root.reset()
        } else {
          return
        }
      }

      BorderSurface {
        id: frame
        z: -1
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Style.controlFill(parent.activeFocus, false, root.foreground, Commons.Color.accent)
        borderSpec: Border.controlSpec(parent.activeFocus ? "focus" : "normal", root.foreground, Commons.Color.accent)
      }
    }
  }

  Column {
    visible: root.manual && root.suggestions.length > 0
    width: parent.width

    Repeater {
      model: root.suggestions

      Rectangle {
        required property var modelData
        required property int index
        readonly property bool current: index === root.highlighted
        width: parent.width
        height: suggestion.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: current ? Style.hoverFillFor(root.foreground, Commons.Color.accent) : "transparent"

        Row {
          id: suggestion
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            id: town
            textFormat: Text.PlainText
            width: Math.min(implicitWidth, parent.width * 0.6)
            elide: Text.ElideRight
            text: modelData.name
            color: current ? Style.hoverStateColor(root.foreground, Commons.Color.accent) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: Math.max(0, parent.width - town.width - parent.spacing)
            anchors.verticalCenter: town.verticalCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: modelData.region
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPositionChanged: root.highlighted = index
          onClicked: root.pick(modelData)
        }
      }
    }
  }

  Text {
    visible: root.manual && root.suggestions.length === 0
    width: parent.width
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    text: root.error || (root.editing ? "Type a town or city"
      : "Sun times for " + (root.place || root.location))
    color: root.error ? root.foreground : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
