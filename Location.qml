import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

Column {
  id: root

  property string location: ""
  property string place: ""
  property string source: "ip"
  property bool locating: false
  property color foreground: Color.foreground
  property color dim: Color.foreground
  property string fontFamily: Style.font.family
  property bool editing: false
  property string error: ""
  property var suggestions: []
  property int highlighted: 0
  property string pendingQuery: ""
  property string activeQuery: ""
  property int revision: 0
  property int activeRevision: -1
  readonly property bool manual: editing || source === "manual"

  signal save(string coordinates, string name)
  signal automatic()

  spacing: Style.spacing.md

  function reset() {
    revision++
    editing = false
    error = ""
    suggestions = []
    search.stop()
    field.text = source === "manual" ? place : ""
  }

  function edit() {
    editing = true
    error = ""
    field.selectAll()
    field.forceActiveFocus()
  }

  function lookup() {
    var query = field.text.trim()
    if (!editing || query.length < 2 || coordinates(query)) {
      suggestions = []
      return
    }
    pendingQuery = query
    if (!geocoder.running) startLookup()
  }

  function startLookup() {
    if (!editing || pendingQuery.length < 2 || pendingQuery !== field.text.trim()) return
    activeRevision = revision
    activeQuery = pendingQuery
    geocoder.command = ["curl", "-fsS", "--max-time", "5",
      "https://geocoding-api.open-meteo.com/v1/search?count=5&language=en&format=json&name=" + encodeURIComponent(activeQuery)]
    geocoder.running = true
  }

  function pick(suggestion) {
    if (!suggestion) return
    revision++
    editing = false
    search.stop()
    error = ""
    suggestions = []
    field.text = suggestion.name
    save(suggestion.latitude + " " + suggestion.longitude, suggestion.name)
  }

  // Enter takes the highlighted city. Coordinates still work for anyone who
  // pastes them, without being something the UI asks for.
  function commit() {
    var position = coordinates(field.text)
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
    error = field.text.trim() === "" ? "Type a town or city" : "No places found. Try a nearby town."
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
    try {
      return (JSON.parse(raw).results || []).filter(function(entry) {
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

  Process {
    id: geocoder
    stdout: StdioCollector { id: response; waitForEnd: true }
    onExited: function(code) {
      Qt.callLater(function() {
        if (!root.editing) return
        if (root.activeRevision !== root.revision || root.activeQuery !== field.text.trim()) {
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

  TextField {
    id: field
    visible: root.manual
    width: parent.width
    placeholderText: "Search city"
    foreground: root.foreground
    font.family: root.fontFamily
    Accessible.name: "Search for your town or city"
    onTextEdited: {
      root.revision++
      root.suggestions = []
      root.highlighted = 0
      root.error = ""
      root.editing = true
      search.restart()
    }
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Down) {
        root.highlighted = Math.max(0, Math.min(root.highlighted + 1, root.suggestions.length - 1))
      } else if (event.key === Qt.Key_Up) {
        root.highlighted = Math.max(root.highlighted - 1, 0)
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.commit()
      } else if (event.key === Qt.Key_Escape && root.editing && root.source === "manual") {
        root.reset()
      } else {
        return
      }
      event.accepted = true
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
        color: current ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

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
            color: current ? Style.hoverStateColor(root.foreground, Color.accent) : root.foreground
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
