import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ToolTip {
  id: root
  readonly property var borderSpec: Border.localOrSurfaceSpec("tooltip", "border", Commons.Color.tooltip.border, Commons.Color.tooltip.border, Style.normalBorderWidth)
  delay: 400
  padding: 0

  background: BorderSurface {
    color: Commons.Color.tooltip.background
    borderSpec: root.borderSpec
    radius: Style.cornerRadius
  }
  contentItem: Text {
    textFormat: Text.PlainText
    text: root.text
    color: Commons.Color.tooltip.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    leftPadding: Border.left(root.borderSpec) + Style.spacing.controlPaddingX
    rightPadding: Border.right(root.borderSpec) + Style.spacing.controlPaddingX
    topPadding: Border.top(root.borderSpec) + Style.spacing.controlPaddingY
    bottomPadding: Border.bottom(root.borderSpec) + Style.spacing.controlPaddingY
  }
}
