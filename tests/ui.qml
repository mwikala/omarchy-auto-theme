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
      city.editing = true
      city.revision++
      city.suggestions = []
      for (var child of city.children)
        if (child.placeholderText === "Search city") child.text = name
      city.lookup()
    }

    Column {
      Choice {
        id: choice
        width: 120
        label: "Background"
        options: ["Default", "New horizons", "A background with an unusually long filename"]
        value: "Default"
      }
      Location { id: city; width: 360 }
      Warmth { id: warmth; width: 360 }
    }

    Connections {
      target: warmth
      function onCommitted(temperature) { window.restored = temperature === 4000 }
    }

    Timer {
      interval: 100
      running: true
      onTriggered: {
        window.check(choice.menuWidth() > choice.width, "long names must widen popup")
        window.check(city.coordinates("51.51, -0.13") === "51.51 -0.13", "coordinate normalization")
        window.check(city.coordinates("91, 2") === "", "coordinate bounds")
        window.check(city.results('{"results":[{"name":"Invalid","latitude":999,"longitude":2}]}').length === 0, "geocoder validation")
        city.editing = true
        city.revision = 3
        city.reset()
        window.check(!city.editing && city.revision === 4, "reset must invalidate active searches")
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
        console.log(window.failures.length ? "FAIL: " + window.failures.join(", ")
          : "PASS: popup widths, palette changes, screen bounds, coordinates, geocoder validation, city-search races, slider reset")
        Qt.quit()
      }
    }
  }
}
