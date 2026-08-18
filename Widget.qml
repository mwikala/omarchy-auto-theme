import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "mwikala.auto-theme"
  ipcTarget: "mwikala.auto-theme"

  // Panel's built-in handler only exposes open/close/toggle, so it is replaced
  // here to add refresh -- that is how the script pushes state after applying a
  // change, instead of the panel waiting on its poll.
  manageIpc: false

  // Resolved against the plugin directory rather than PATH: the shell's PATH
  // has no ~/.local/bin, and this keeps the plugin self-contained wherever it
  // is installed.
  readonly property string script: Qt.resolvedUrl("bin/omarchy-auto-theme")
    .toString()
    .replace(/^file:\/\//, "")

  property string mode: ""
  property bool followSun: false
  property string nightlight: "off"
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
  property var themes: []

  readonly property string label: mode === "light" ? "󰖨" : mode === "dark" ? "󰖔" : "󰔎"
  readonly property string klass: followSun ? "active" : ""

  readonly property color panelForeground: bar ? bar.foreground : Color.foreground
  readonly property string panelFontFamily: bar ? bar.fontFamily : Style.font.family

  // Auto is a third choice rather than a separate switch, so the control has
  // one value: an explicit mode, or following the sun.
  readonly property string selection: followSun ? "auto" : mode

  // Says what the current selection means: what Auto will do next, or when the
  // sun turns if you are driving it yourself.
  readonly property string schedule: {
    if (followSun && nextChange.indexOf(":") !== -1) {
      return (mode === "light" ? "Light" : "Dark")
        + " until " + (nextEvent === "sunset" ? "sunset" : "sunrise")
        + " at " + nextChange
    }
    if (sunrise === "" && sunset === "") return ""
    return "Sunrise " + sunrise + " · Sunset " + sunset
  }

  // Night light Auto follows the same sun times: on after sunset, off after sunrise.
  readonly property string nightlightSchedule: {
    if (nightlight !== "auto" || nextChange.indexOf(":") === -1) return ""
    return (nextEvent === "sunrise" ? "On" : "Off")
      + " until " + (nextEvent === "sunset" ? "sunset" : "sunrise")
      + " at " + nextChange
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function run(args) {
    if (root.bar) root.bar.run(root.script + " " + args)
    settleTimer.restart()
  }

  // Paint the choice before the script has finished applying it. The refresh
  // that follows reconciles, but the control never appears to lag the click.
  function select(value) {
    if (value === "auto") {
      followSun = true
    } else {
      followSun = false
      mode = value
    }
    run(value === "auto" ? "enable" : "mode " + value)
  }

  function selectNightlight(value) {
    nightlight = value
    run("nightlight " + value)
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  function chooseTheme(slot, name) {
    if (!name) return
    run("config " + slot + " \"" + name + "\"")
  }

  function chooseBackground(slot, name) {
    if (slot === "light") lightBackground = name
    else darkBackground = name
    run("config " + slot + "-bg \"" + name + "\"")
  }

  // Empty means omarchy keeps cycling to whatever comes next, which is what it
  // does without this plugin.
  function backgroundOptions(names) {
    var out = [{ value: "", label: "Default" }]
    for (var i = 0; i < names.length; i++)
      out.push({ value: names[i], label: root.backgroundLabel(names[i]) })
    return out
  }

  // Theme backgrounds are ordered by a numeric prefix: "1-dark-waters.jpg"
  // reads as "Dark waters".
  function backgroundLabel(name) {
    var base = name.replace(/\.[^.]+$/, "").replace(/^\d+[-_]/, "").replace(/[-_]/g, " ")
    return base.charAt(0).toUpperCase() + base.slice(1)
  }

  Component.onCompleted: {
    refresh()
    themesProc.running = true
  }

  onOpenedChanged: if (opened) refresh()

  Process {
    id: stateProc
    command: [root.script, "panel-json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var s = JSON.parse(String(text || "").trim())
          root.mode = s.mode || ""
          root.followSun = s.auto === true
          root.nightlight = s.nightlight || "off"
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
        } catch (e) {
          root.mode = ""
        }
      }
    }
  }

  Process {
    id: themesProc
    command: ["omarchy-theme-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n").filter(function(l) { return l.trim() !== "" })
        root.themes = lines
      }
    }
  }

  // Mode changes apply in a background subshell, so re-read once it has settled.
  Timer {
    id: settleTimer
    interval: 900
    onTriggered: root.refresh()
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
    active: root.klass === "active"
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ButtonGroup sizes its chips to their labels, which leaves the row
        // short against the full-width fields below. Equal thirds instead, so
        // the control spans the panel like a segmented control.
        Row {
          id: modes
          width: parent.width
          spacing: Style.spacing.md

          readonly property real segment: (width - spacing * 2) / 3

          Repeater {
            model: [
              { value: "light", label: "Light", icon: "󰖨" },
              { value: "dark", label: "Dark", icon: "󰖔" },
              { value: "auto", label: "Auto", icon: "󰔎" }
            ]

            Button {
              required property var modelData
              width: modes.segment
              text: modelData.label
              iconText: modelData.icon
              bordered: true
              selected: root.selection === modelData.value
              foreground: root.panelForeground
              fontFamily: root.panelFontFamily
              onClicked: root.select(modelData.value)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.schedule !== ""
          text: root.schedule
          color: Qt.darker(root.panelForeground, 1.4)
          font.family: root.panelFontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        PanelSeparator {
          width: parent.width
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        PanelSectionHeader {
          text: "NIGHT LIGHT"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Row {
          id: nightlights
          width: parent.width
          spacing: Style.spacing.md

          readonly property real segment: (width - spacing * 2) / 3

          Repeater {
            model: [
              { value: "on", label: "On", icon: "󰃝" },
              { value: "off", label: "Off", icon: "󰃞" },
              { value: "auto", label: "Auto", icon: "󰔎" }
            ]

            Button {
              required property var modelData
              width: nightlights.segment
              text: modelData.label
              iconText: modelData.icon
              bordered: true
              selected: root.nightlight === modelData.value
              foreground: root.panelForeground
              fontFamily: root.panelFontFamily
              onClicked: root.selectNightlight(modelData.value)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.nightlightSchedule !== ""
          text: root.nightlightSchedule
          color: Qt.darker(root.panelForeground, 1.4)
          font.family: root.panelFontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        PanelSeparator {
          width: parent.width
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        PanelSectionHeader {
          text: "THEMES"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Dropdown {
          width: parent.width
          label: "Light"
          value: root.lightTheme
          options: root.themes
          onChanged: function(selected) { root.chooseTheme("light", selected) }
        }

        Dropdown {
          width: parent.width
          label: "Dark"
          value: root.darkTheme
          options: root.themes
          onChanged: function(selected) { root.chooseTheme("dark", selected) }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        PanelSectionHeader {
          text: "BACKGROUNDS"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Dropdown {
          width: parent.width
          label: "Light"
          value: root.lightBackground
          options: root.backgroundOptions(root.lightBackgrounds)
          onChanged: function(selected) { root.chooseBackground("light", selected) }
        }

        Dropdown {
          width: parent.width
          label: "Dark"
          value: root.darkBackground
          options: root.backgroundOptions(root.darkBackgrounds)
          onChanged: function(selected) { root.chooseBackground("dark", selected) }
        }
      }
    }
  }
}
