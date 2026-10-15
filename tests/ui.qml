import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons

ShellRoot {
  Window {
    id: window
    visible: true
    width: 600
    height: 600
    property var failures: []
    property bool restored: false
    property var saved: ({})
    property string draft: ""

    function check(condition, message) {
      if (!condition) failures.push(message)
    }

    function palette(background, foreground) {
      Commons.Color.background = background
      Commons.Color.foreground = foreground
      Commons.Color.accent = foreground
      Commons.Color.shellValues = Object.assign({}, Commons.Color.shellValues, {
        "popups.background": background,
        "popups.background-alpha": "1",
        "popups.text": foreground
      })
    }

    function checkPalette(background, foreground) {
      window.check(choice.popup.background.color.toString() === background, "popup surface must follow the palette")
      window.check(choice.foreground.toString() === foreground, "picker text must follow the palette")
      var option = choice.popup.contentItem.itemAtIndex(0)
      window.check(option !== null, "menu option must be visible")
      if (!option) return
      var ink = option.highlighted || option.hovered
        ? Style.hoverStateColor(choice.foreground, Commons.Color.accent).toString() : foreground
      window.check(option.contentItem.color.toString() === ink, "menu text must follow the palette")
    }

    function query(name) {
      city.edit()
      city.revision++
      city.suggestions = []
      city.query = name
      city.lookup()
    }

    function input(node) {
      if (node.placeholderText === "Search city") return node
      for (var child of node.children || []) {
        var field = input(child)
        if (field) return field
      }
      return null
    }

    Column {
      id: controls
      Choice {
        id: choice
        width: 120
        label: "Background"
        options: ["Default", "New horizons", "A background with an unusually long filename"]
        value: "Default"
      }
      Location { id: city; width: 360 }
      Warmth { id: warmth; width: 360 }
      Hint { id: hint; text: "<img src='https://example.invalid/tracker'>" }
    }

    Connections {
      target: warmth
      function onCommitted(temperature) { window.restored = temperature === 4000 }
    }

    Connections {
      target: city
      function onSave(coordinates, name) { window.saved = { coordinates: coordinates, name: name } }
    }

    Timer {
      interval: 100
      running: true
      onTriggered: {
        window.check(!window.input(city), "automatic location must not create an input")
        window.check(hint.contentItem.textFormat === Text.PlainText && hint.contentItem.text === hint.text, "tooltip markup must remain literal")
        city.source = "manual"
        city.place = "London"
        window.check(!window.input(city), "saved manual location must not create an input")
        city.edit()
        var field = window.input(city)
        window.check(field && field.text === "London", "manual edit must create the saved city input")
        window.check(field && field.width === city.width && field.height > 0, "loaded input must retain its layout")
        choice.forceActiveFocus()
        window.check(field && field.readOnly, "unfocused input must not read clipboard text")
        if (field) field.forceActiveFocus()
        window.check(field && field.readOnly, "focused input must never enable native clipboard reads")
        city.source = "ip"
        window.check(choice.menuWidth() > choice.width, "long names must widen popup")
        window.check(!choice.editable, "theme pickers must not create writable native input")
        window.check(city.coordinates("51.51, -0.13") === "51.51 -0.13", "coordinate normalization")
        window.check(city.coordinates("91, 2") === "", "coordinate bounds")
        window.check(city.results('{"results":[{"name":"Invalid","latitude":999,"longitude":2}]}').length === 0, "geocoder validation")
        window.check(city.results('{"results":{}}').length === 0, "non-array geocoder results must be rejected")
        window.check(city.results('{"results":[null,{}, {"name":"Bad","admin1":{},"latitude":1,"longitude":2}]}').length === 0, "invalid geocoder shapes must be rejected")
        window.check(city.results(JSON.stringify({ results: [{ name: "x".repeat(129), latitude: 1, longitude: 2 }] })).length === 0, "long geocoder names must be rejected")
        window.check(city.results(JSON.stringify({ results: Array(20).fill({ name: "City", latitude: 1, longitude: 2 }) })).length === 5, "geocoder collections must be bounded")
        city.editing = true
        city.revision = 3
        city.reset()
        window.check(!city.editing && city.revision === 4, "reset must invalidate active searches")
        window.check(!window.input(city), "reset must destroy the input")
        warmth.adjust(2500)
        warmth.restore()
        window.check(warmth.preview === 4000 && window.restored, "slider reset")
        window.palette("#15191e", "#e6eef5")
        choice.open()
        window.query("Paris")
      }
    }

    Timer { interval: 200; running: true; onTriggered: window.query("Berlin") }

    Timer {
      interval: 300
      running: true
      onTriggered: {
        window.check(choice.popup.width >= choice.menuWidth(), "open popup must fit full labels")
        window.checkPalette("#15191e", "#e6eef5")
        window.palette("#f4f0e8", "#252a30")
        choice.options = ["An extremely long background name ".repeat(30)]
      }
    }

    Timer {
      interval: 650
      running: true
      onTriggered: {
        window.check(choice.popup.width <= window.width, "oversized menu must stay on screen")
        window.checkPalette("#f4f0e8", "#252a30")
        window.palette("#15191e", "#e6eef5")
        window.check(city.suggestions.length === 1 && city.suggestions[0].name === "Berlin", "latest city query must win")
        window.query("Paris")
        city.reset()
        window.check(!window.input(city), "cancelling a pending search must destroy the input")
        choice.close()
      }
    }

    Timer { interval: 800; running: true; onTriggered: choice.open() }

    Timer {
      interval: 1100
      running: true
      onTriggered: {
        window.check(city.suggestions.length === 0 && !city.editing, "cancelled search must stay closed")
        window.checkPalette("#15191e", "#e6eef5")
        choice.close()
        city.source = "manual"
        city.edit()
        var field = window.input(city)
        if (field) {
          field.text = "Berlin"
          field.edited()
        }
        window.check(city.query === "Berlin", "editing must update the search query")
        city.pick({ name: "Berlin", latitude: 52.52, longitude: 13.41 })
        window.check(!window.input(city), "selecting a city must destroy the input")
        window.check(window.saved.name === "Berlin" && window.saved.coordinates === "52.52 13.41", "city selection must save coordinates")
        city.edit()
        city.query = "51.51, -0.13"
        city.commit()
        window.check(!window.input(city) && window.saved.coordinates === "51.51 -0.13", "saving coordinates must destroy the input")
        city.edit()
        controls.visible = false
        window.check(!window.input(city) && !city.editing, "hiding the panel must destroy and reset the input")
        controls.visible = true
        window.check(!window.input(city), "reopening the panel must not recreate an input")
        city.edit()
        for (var child of city.children)
          if (child.caption === "Location") child.selected("auto")
        window.check(!window.input(city) && !city.editing, "automatic mode must destroy the input")
        city.edit()
        city.paste(false)
      }
    }

    Timer {
      interval: 1400
      running: true
      onTriggered: {
        window.check(city.query === "Berlin", "explicit paste must insert bounded text")
        var field = window.input(city)
        field.selectAll()
        field.replace("Paris")
        city.paste(false)
        field.replace("X")
        window.draft = city.query
      }
    }

    Timer {
      interval: 1700
      running: true
      onTriggered: {
        window.check(city.query === window.draft, "paste must not overwrite edits made while reading")
        city.paste(false)
        controls.visible = false
      }
    }

    Timer {
      interval: 2100
      running: true
      onTriggered: {
        controls.visible = true
        window.check(!window.input(city) && !city.editing, "late paste must not recreate a closed input")
        console.log(window.failures.length ? "FAIL: " + window.failures.join(", ")
          : "PASS: popup widths, palette changes, screen bounds, coordinates, geocoder validation, city-search races, editor lifetime, bounded paste, literal tooltips, slider reset")
        Qt.quit()
      }
    }
  }
}
