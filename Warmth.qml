import QtQuick
import qs.Commons

Item {
  id: root

  property int temperature: 4000
  property int standard: 4000
  property color foreground: Color.foreground
  property bool active: false
  readonly property bool dragging: pointer.pressed
  property int preview: temperature
  property bool restoring: false

  signal moved(int temperature)
  signal committed(int temperature)
  signal cancelled()

  implicitHeight: Style.spacing.controlHeight
  activeFocusOnTab: true
  Accessible.role: Accessible.Slider
  Accessible.name: "Night light warmth"
  Accessible.description: preview + " Kelvin. Right is warmer. Delete restores " + standard + " Kelvin."

  onTemperatureChanged: if (!dragging) preview = temperature

  function adjust(kelvin) {
    preview = Math.max(2500, Math.min(5500, Math.round(kelvin / 100) * 100))
  }

  function restore() {
    adjust(standard)
    committed(preview)
  }

  function point(position) {
    adjust(5500 - Math.max(0, Math.min(1, position / width)) * 3000)
    moved(preview)
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Left) {
      adjust(preview + (event.key === Qt.Key_Right ? -100 : 100))
      committed(preview)
      event.accepted = true
    } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
      adjust(event.key === Qt.Key_Home ? 5500 : 2500)
      committed(preview)
      event.accepted = true
    } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
      restore()
      event.accepted = true
    }
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: Style.space(4)
    radius: height / 2
    color: Util.alpha(root.foreground, 0.16)

    Rectangle {
      width: parent.width * (5500 - root.preview) / 3000
      height: parent.height
      radius: parent.radius
      color: Util.alpha(root.foreground, root.active || root.dragging ? 0.85 : 0.4)
    }
  }

  Rectangle {
    width: Style.space(14)
    height: width
    radius: width / 2
    x: Math.max(0, Math.min(root.width - width, root.width * (5500 - root.preview) / 3000 - width / 2))
    anchors.verticalCenter: track.verticalCenter
    color: root.foreground
    opacity: root.active || root.dragging || root.activeFocus ? 1 : 0.5
    border.width: root.activeFocus ? Style.space(2) : 0
    border.color: Color.accent
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onPressed: function(mouse) {
      root.forceActiveFocus()
      if (mouse.button === Qt.MiddleButton) root.restore()
      else root.point(mouse.x)
    }
    onPositionChanged: function(mouse) { if (pressedButtons & Qt.LeftButton && !root.restoring) root.point(mouse.x) }
    // The second press of a double-click has already moved the knob; the
    // release that follows then saves the restored value instead.
    onDoubleClicked: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.restoring = true
      root.adjust(root.standard)
    }
    onReleased: function(mouse) {
      root.restoring = false
      if (mouse.button === Qt.LeftButton) root.committed(root.preview)
    }
    onCanceled: { root.restoring = false; root.preview = root.temperature; root.cancelled() }
    onWheel: function(wheel) {
      root.adjust(root.preview + (wheel.angleDelta.y > 0 ? -100 : 100))
      root.committed(root.preview)
    }
  }
}
