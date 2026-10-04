import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "mwikala.auto-theme"
  ipcTarget: "mwikala.auto-theme"

  // Panel's built-in handler only exposes open/close/toggle; the script also
  // needs refresh to push state after it applies a change.
  manageIpc: false

  // The shell's PATH has no ~/.local/bin, so resolve the engine inside the
  // plugin wherever it is installed.
  readonly property string script: decodeURIComponent(Qt.resolvedUrl("bin/omarchy-auto-theme")
    .toString()
    .replace(/^file:\/\//, ""))

  property string mode: ""
  property bool followSun: false
  property string nightlight: "off"
  property string nightlightState: "off"
  property int temperature: 4000
  property int shownTemperature: temperature
  property string temperatureDisplay: "name"
  property string lightTheme: ""
  property string darkTheme: ""
  property string lightBackground: ""
  property string darkBackground: ""
  property var lightBackgrounds: []
  property var darkBackgrounds: []
  property string nextChange: ""
  property string nextEvent: ""
  property string sunrise: ""
  property string sunset: ""
  property string issue: ""
  property string location: ""
  property string locationSource: "ip"
  property string place: ""
  property bool locationOpen: false
  property var themes: []
  property bool themesOpen: false
  property var pending: []
  property string failure: ""
  property bool previewing: false
  property bool pointerDisclosure: false
  property bool executing: false
  property bool refreshPending: false
  property int revision: 0
  readonly property bool busy: executing || pending.length > 0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string label: mode === "light" ? "󰖨" : mode === "dark" ? "󰖔" : "󰔎"
  readonly property string selection: followSun ? "auto" : mode
  readonly property bool nightlightActive: nightlight === "on" || (nightlight === "auto" && nightlightState === "on")

  readonly property string schedule: {
    if (issue === "sunwait") return "Needs sunwait"
    if (issue === "location") return locateProc.running ? "Locating…" : "Set location"
    if (issue === "polar") return "Polar"

    var time = nextChange || (nextEvent === "sunrise" ? sunrise : sunset)
    if (!time) return ""
    return (nextEvent === "sunrise" ? "󰖜 " : "󰖛 ") + time
  }

  function refresh() {
    if (busy || previewing) return
    if (stateProc.running) { refreshPending = true; return }
    refreshPending = false
    stateProc.revision = revision
    stateProc.running = true
  }

  function run(args) {
    revision++
    failure = ""
    // Coalesce drags and rapid mode changes, keeping the final save after any
    // preview already in flight. Arguments never pass through a shell string.
    pending = pending.filter(function(command) {
      if (command[0] === "preview-temperature") return false
      return command[0] !== args[0] || command[0] === "config"
    }).concat([args])
    drain()
  }

  function drain() {
    if (executing || pending.length === 0) return
    executing = true
    commandProc.command = [root.script].concat(pending[0])
    pending = pending.slice(1)
    commandProc.running = true
  }

  function selectMode(value) {
    followSun = value === "auto"
    if (value !== "auto") mode = value
    run(value === "auto" ? ["enable"] : ["mode", value])
  }

  function selectNightlight(value) {
    nightlight = value
    run(["nightlight", value])
  }

  function previewTemperature(value) {
    previewing = true
    shownTemperature = value
    run(["preview-temperature", String(value)])
  }

  function saveTemperature(value) {
    previewing = false
    shownTemperature = value
    run(["temperature", String(value)])
  }

  function cancelPreview() {
    if (!previewing) return
    previewing = false
    run(["temperature", String(temperature)])
  }

  // Bands follow familiar light sources, from barely tinted to candlelight.
  function warmthName(kelvin) {
    if (kelvin >= 5100) return "Subtle"
    if (kelvin >= 4400) return "Soft"
    if (kelvin >= 3700) return "Warm"
    if (kelvin >= 3000) return "Cosy"
    return "Candlelight"
  }

  function formatWarmth(kelvin, display) {
    return display === "kelvin" ? kelvin + "K" : warmthName(kelvin)
  }

  function toggleTemperatureDisplay() {
    temperatureDisplay = temperatureDisplay === "kelvin" ? "name" : "kelvin"
    run(["temperature-display", temperatureDisplay])
  }

  function themeFor(slot) { return slot === "light" ? lightTheme : darkTheme }
  function backgroundFor(slot) { return slot === "light" ? lightBackground : darkBackground }
  function backgroundsFor(slot) { return slot === "light" ? lightBackgrounds : darkBackgrounds }

  function chooseTheme(slot, name) {
    if (!name || name === themeFor(slot)) return

    if (slot === "light") {
      lightTheme = name
      lightBackground = ""
    } else {
      darkTheme = name
      darkBackground = ""
    }

    run(["config", slot, name])
  }

  function chooseBackground(slot, name) {
    if (slot === "light") lightBackground = name
    else darkBackground = name
    run(["config", slot + "-bg", name])
  }

  // Empty keeps omarchy cycling to whatever comes next, which is what it does
  // without this plugin.
  function backgroundOptions(names) {
    var options = [{ value: "", label: "Default" }]
    for (var i = 0; i < names.length; i++)
      options.push({ value: names[i], label: backgroundLabel(names[i]) })
    return options
  }

  // Theme backgrounds are ordered by a numeric prefix: "1-dark-waters.jpg"
  // reads as "Dark waters".
  function backgroundLabel(name) {
    var base = name.replace(/\.[^.]+$/, "").replace(/^\d+[-_]/, "").replace(/[-_]/g, " ")
    return base.charAt(0).toUpperCase() + base.slice(1)
  }

  IpcHandler {
    id: ipcHandler

    // Newer Quattro shells also route IPC through their socket registry.
    Component.onCompleted: {
      if (typeof IpcRegistry !== "undefined") IpcRegistry.register(ipcHandler)
    }
    Component.onDestruction: {
      if (typeof IpcRegistry !== "undefined") IpcRegistry.unregister(ipcHandler)
    }
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  Component.onCompleted: {
    refresh()
    themesProc.running = true
  }

  function toggleLocation() {
    locationOpen = !locationOpen
    if (locationOpen) locationEditor.reset()
  }

  onOpenedChanged: {
    if (!opened) { cancelPreview(); locationOpen = false; locationEditor.reset(); return }
    refresh()
    if (!locateProc.running) locateProc.running = true
    if (!themesProc.running) themesProc.running = true
  }

  Process {
    id: stateProc
    property int revision: 0
    command: [root.script, "panel-json"]
    onExited: Qt.callLater(function() { if (root.refreshPending) root.refresh() })
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.busy || root.previewing || stateProc.revision !== root.revision) {
          root.refreshPending = true
          return
        }
        try {
          var s = JSON.parse(String(text || "").trim())
          root.mode = s.mode || ""
          root.followSun = s.auto === true
          root.nightlight = s.nightlight || "off"
          root.nightlightState = s.nightlightState || "off"
          root.temperature = s.temperature || 4000
          root.temperatureDisplay = s.temperatureDisplay || "name"
          if (!slider.dragging) root.shownTemperature = root.temperature
          root.lightTheme = s.lightTheme || ""
          root.darkTheme = s.darkTheme || ""
          root.lightBackground = s.lightBackground || ""
          root.darkBackground = s.darkBackground || ""
          root.lightBackgrounds = s.lightBackgrounds || []
          root.darkBackgrounds = s.darkBackgrounds || []
          root.nextChange = s.nextChange || ""
          root.nextEvent = s.nextEvent || ""
          root.sunrise = s.sunrise || ""
          root.sunset = s.sunset || ""
          root.issue = s.issue || ""
          root.location = s.location || ""
          root.locationSource = s.locationSource || "ip"
          root.place = s.place || ""
        } catch (e) { root.failure = "Could not read Auto Theme status." }
      }
    }
  }

  // Refreshes the automatic location when its cache is stale; a no-op for
  // manual coordinates and otherwise quick, so it runs on every open.
  Process {
    id: locateProc
    command: [root.script, "locate"]
    onExited: Qt.callLater(root.refresh)
  }

  Process {
    id: themesProc
    command: ["omarchy-theme-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.themes = String(text || "").split("\n").filter(function(line) { return line.trim() !== "" })
    }
  }

  Process {
    id: commandProc
    stderr: StdioCollector { id: commandError; waitForEnd: true }
    onExited: function(exitCode) {
      root.executing = false
      var message = String(commandError.text || "Could not apply the change.").trim()
      if (command[1] === "location") {
        if (exitCode === 0) Qt.callLater(locationEditor.reset)
        else locationEditor.error = message
      } else if (exitCode !== 0) {
        root.failure = message
      }
      Qt.callLater(function() {
        root.drain()
        root.refresh()
      })
    }
  }

  Timer {
    interval: Math.max(10, root.setting("refreshIntervalSec", 60)) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    active: root.followSun
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Flickable {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

        Item {
          width: parent.width
          height: Math.max(Style.spacing.controlHeight, heroLabel.implicitHeight)

          OpticalGlyph {
            id: heroIcon
            width: Style.font.heading
            height: Style.font.heading
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            fontFamily: root.fontFamily
            fontSize: Style.font.heading
            color: root.foreground
          }

          Text {
            id: heroLabel
            textFormat: Text.PlainText
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(8)
            anchors.right: schedule.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.mode === "light" ? "Light" : root.mode === "dark" ? "Dark" : "Theme"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.iconLarge
            font.weight: Font.Medium
            elide: Text.ElideRight
            HoverHandler { id: themeHover }
            PanelToolTip {
              visible: themeHover.hovered
              text: root.themeFor(root.mode)
            }
          }

          // The sun times depend on location, so this readout is also where
          // location is changed.
          Item {
            id: schedule
            width: scheduleLabel.implicitWidth + Style.space(16)
            height: parent.height
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Location: " + (root.place || root.location || "not set")
            Keys.onReturnPressed: root.toggleLocation()
            Keys.onSpacePressed: root.toggleLocation()
            HoverHandler { id: scheduleHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.toggleLocation() }

            Text {
              id: scheduleLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.schedule
              color: root.locationOpen || scheduleHover.hovered || schedule.activeFocus || root.issue === "location" ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.underline: schedule.activeFocus
            }

            PanelToolTip {
              visible: scheduleHover.hovered && !root.locationOpen
              text: {
                if (root.issue === "sunwait") return "Install sunwait from the AUR to enable Auto"
                if (root.issue === "location") return "Set your location"
                var where = root.place || "your location"
                var when = root.issue === "polar" ? "No sunrise or sunset today" : (root.nextEvent === "sunrise" ? "Sunrise" : "Sunset")
                return when + " in " + where + " · Change"
              }
            }
          }
        }

        Location {
          id: locationEditor
          visible: root.locationOpen
          width: parent.width
          location: root.location
          place: root.place
          source: root.locationSource
          locating: locateProc.running
          foreground: root.foreground
          dim: root.dim
          fontFamily: root.fontFamily
          onSave: function(coordinates, name) { root.run(["location", coordinates, name]) }
          onAutomatic: root.run(["location", "auto"])
        }

        PanelSeparator {
          visible: root.locationOpen
          width: parent.width
          foreground: root.foreground
        }

        Segments {
          width: parent.width
          caption: "Theme mode"
          options: [
            { value: "light", label: "Light" },
            { value: "dark", label: "Dark" },
            { value: "auto", label: "Auto" }
          ]
          value: root.selection
          foreground: root.foreground
          fontFamily: root.fontFamily
          onSelected: function(value) { root.selectMode(value) }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Item {
          width: parent.width
          height: Math.max(nightIcon.height, temperatureText.implicitHeight)

          OpticalGlyph {
            id: nightIcon
            width: Style.font.icon
            height: Style.font.icon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃝"
            fontFamily: root.fontFamily
            fontSize: Style.font.icon
            color: root.nightlightActive ? root.foreground : root.dim
            HoverHandler { id: nightHover }
            PanelToolTip {
              visible: nightHover.hovered
              text: "Night light"
            }
          }

          Text {
            id: temperatureText
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatWarmth(root.shownTemperature, root.temperatureDisplay)
            color: root.nightlightActive || slider.dragging || readoutHover.hovered ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            activeFocusOnTab: true
            Keys.onReturnPressed: root.toggleTemperatureDisplay()
            Keys.onSpacePressed: root.toggleTemperatureDisplay()
            Accessible.role: Accessible.Button
            Accessible.name: "Night light warmth " + root.formatWarmth(root.shownTemperature, "name") + ", " + root.shownTemperature + " Kelvin"
            HoverHandler { id: readoutHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton
              onTapped: root.toggleTemperatureDisplay()
            }
            PanelToolTip {
              visible: readoutHover.hovered
              text: root.formatWarmth(root.shownTemperature, root.temperatureDisplay === "kelvin" ? "name" : "kelvin")
            }
          }
        }

        Segments {
          width: parent.width
          caption: "Night light"
          options: [
            { value: "on", label: "On" },
            { value: "off", label: "Off" },
            { value: "auto", label: "Auto" }
          ]
          value: root.nightlight
          foreground: root.foreground
          fontFamily: root.fontFamily
          onSelected: function(value) { root.selectNightlight(value) }
        }

        Warmth {
          id: slider
          width: parent.width
          foreground: root.foreground
          active: root.nightlightActive
          temperature: root.temperature
          onMoved: function(kelvin) { root.previewTemperature(kelvin) }
          onCommitted: function(kelvin) { root.saveTemperature(kelvin) }
          onCancelled: root.cancelPreview()
          HoverHandler { id: warmthHover }
          PanelToolTip {
            visible: warmthHover.hovered && !slider.dragging
            text: "Warmer to the right · double-click to reset"
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Item {
          id: disclosure
          width: parent.width
          height: Style.spacing.controlHeight
          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: "Themes and backgrounds"
          Accessible.description: root.themesOpen ? "Expanded" : "Collapsed"
          function toggle(pointer) {
            root.pointerDisclosure = pointer
            root.themesOpen = !root.themesOpen
          }
          Keys.onReturnPressed: toggle(false)
          Keys.onSpacePressed: toggle(false)

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Themes"
            color: themesHover.hovered || disclosure.activeFocus ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            rotation: root.themesOpen ? 180 : 0
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body

            Behavior on rotation {
              enabled: root.pointerDisclosure
              NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
            }
          }

          HoverHandler {
            id: themesHover
            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            onTapped: disclosure.toggle(true)
          }
        }

        Item {
          width: parent.width
          height: root.themesOpen ? themeRows.implicitHeight : 0
          visible: height > 0
          enabled: root.themesOpen

          Column {
            id: themeRows
            width: parent.width
            spacing: Style.spacing.lg
            opacity: root.themesOpen ? 1 : 0

            Behavior on opacity {
              enabled: root.pointerDisclosure
              NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
            }

            Repeater {
              model: ["light", "dark"]

              Row {
                id: themeRow
                required property string modelData
                width: themeRows.width
                spacing: Style.spacing.lg

                readonly property real fields: width - slotIcon.width - spacing * 2

                OpticalGlyph {
                  id: slotIcon
                  width: Style.font.icon
                  height: Style.spacing.controlHeight
                  text: themeRow.modelData === "light" ? "󰖨" : "󰖔"
                  fontFamily: root.fontFamily
                  fontSize: Style.font.icon
                  color: root.dim
                }

                Choice {
                  width: Math.round(themeRow.fields * 0.62)
                  label: themeRow.modelData + " theme"
                  value: root.themeFor(themeRow.modelData)
                  options: root.themes
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onChanged: function(selected) { root.chooseTheme(themeRow.modelData, selected) }
                  HoverHandler { id: choiceHover }
                  PanelToolTip {
                    visible: choiceHover.hovered && !parent.popupOpen
                    text: root.themeFor(themeRow.modelData)
                  }
                }

                Choice {
                  width: themeRow.fields - Math.round(themeRow.fields * 0.62)
                  label: themeRow.modelData + " background"
                  value: root.backgroundFor(themeRow.modelData)
                  options: root.backgroundOptions(root.backgroundsFor(themeRow.modelData))
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onChanged: function(selected) { root.chooseBackground(themeRow.modelData, selected) }
                  HoverHandler { id: backgroundHover }
                  PanelToolTip {
                    visible: backgroundHover.hovered && !parent.popupOpen
                    text: "Background: " + (root.backgroundFor(themeRow.modelData) || "Default")
                  }
                }
              }
            }
          }
        }

        Text {
          visible: root.failure !== ""
          width: parent.width
          textFormat: Text.PlainText
          text: root.failure
          wrapMode: Text.Wrap
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
