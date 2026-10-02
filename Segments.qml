import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var options: []
  property string value: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string caption: ""

  signal selected(string value)

  implicitHeight: Style.spacing.controlHeight + Style.spacing.xs * 2
  radius: Style.cornerRadius
  color: Style.normalFillFor(foreground, Color.accent)

  Row {
    id: row
    anchors.fill: parent
    anchors.margins: Style.spacing.xs
    spacing: Style.spacing.xs

    readonly property real segment: (width - spacing * Math.max(0, root.options.length - 1)) / Math.max(1, root.options.length)

    Repeater {
      model: root.options

      Button {
        required property var modelData
        width: row.segment
        height: row.height
        text: modelData.label
        selected: root.value === modelData.value
        focusable: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: root.caption + ": " + modelData.label
        Accessible.checkable: true
        Accessible.checked: selected
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.selected(modelData.value)
      }
    }
  }
}
