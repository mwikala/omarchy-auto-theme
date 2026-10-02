import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

ComboBox {
  id: root

  property string label: ""
  property string value: ""
  property var options: []
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family
  readonly property var borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
  readonly property bool popupOpen: popup.opened

  signal changed(string value)

  function open() { popup.open() }
  function close() { popup.close() }

  function choose(index) {
    if (index < 0 || index >= model.length) return
    changed(model[index].value)
    popup.close()
  }

  function menuWidth() {
    var widest = width
    for (var option of model)
      widest = Math.max(widest, metrics.advanceWidth(option.label) + Style.spacing.controlPaddingX * 2
        + Border.left(borderSpec) + Border.right(borderSpec) + Style.spacing.hairline * 2)
    return Math.ceil(widest)
  }

  implicitHeight: Style.spacing.controlHeight
  font.family: fontFamily
  font.pixelSize: Style.font.body
  hoverEnabled: true
  textRole: "label"
  valueRole: "value"
  model: options.map(function(option) {
    return typeof option === "object"
      ? { value: String(option.value), label: String(option.label) }
      : { value: String(option), label: String(option) }
  })
  currentIndex: {
    for (var index = 0; index < model.length; index++)
      if (model[index].value === value) return index
    return -1
  }
  Accessible.name: label
  onActivated: function(index) { choose(index) }

  FontMetrics {
    id: metrics
    font: root.font
  }

  background: BorderSurface {
    id: frame
    radius: Style.cornerRadius
    color: Style.controlFill(root.activeFocus, root.hovered, root.foreground, Color.accent)
    borderSpec: Border.controlSpec(root.activeFocus ? "focus" : (root.hovered ? "hover-cursor" : "normal"), root.foreground, Color.accent)
  }

  contentItem: Text {
    leftPadding: frame.borderLeft + Style.spacing.controlPaddingX
    rightPadding: root.indicator.width + frame.borderRight + Style.spacing.md + Style.spacing.controlGap
    textFormat: Text.PlainText
    text: root.currentText || root.value
    font: root.font
    color: root.foreground
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  indicator: Text {
    x: root.width - width - frame.borderRight - Style.spacing.controlGap
    anchors.verticalCenter: parent.verticalCenter
    text: "󰅀"
    font: root.font
    color: Qt.darker(root.foreground, 1.2)
  }

  delegate: ItemDelegate {
    id: option
    required property var modelData
    required property int index
    width: choices.width
    height: Style.spacing.popupRowHeight
    highlighted: root.highlightedIndex === index
    hoverEnabled: true
    onClicked: root.choose(index)
    Accessible.name: modelData.label

    background: Rectangle {
      color: option.highlighted || option.hovered
        ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
    }

    contentItem: Text {
      textFormat: Text.PlainText
      text: option.modelData.label
      font: root.font
      color: option.highlighted || option.hovered
        ? Style.hoverStateColor(root.foreground, Color.accent) : root.foreground
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    leftPadding: Style.spacing.controlPaddingX
    rightPadding: Style.spacing.controlPaddingX

    PanelToolTip {
      visible: option.hovered && root.metricsWidth(option.modelData.label) > option.availableWidth
      text: option.modelData.label
    }
  }

  function metricsWidth(text) { return metrics.advanceWidth(text) }

  popup: Popup {
    focus: true
    width: Math.min(root.menuWidth(), Overlay.overlay ? Overlay.overlay.width - margins * 2 : root.menuWidth())
    x: root.width - width
    y: root.height + Style.spacing.xxs
    margins: Style.spacing.lg
    implicitHeight: Math.min(choices.contentHeight + topPadding + bottomPadding,
      Style.spacing.popupRowHeight * 8 + Style.spacing.labelGap * 7 + topPadding + bottomPadding)
    leftPadding: Border.left(root.borderSpec) + Style.spacing.hairline
    rightPadding: Border.right(root.borderSpec) + Style.spacing.hairline
    topPadding: Border.top(root.borderSpec) + Style.spacing.hairline
    bottomPadding: Border.bottom(root.borderSpec) + Style.spacing.hairline

    background: BorderSurface {
      color: Color.popups.background
      borderSpec: root.borderSpec
      radius: Style.cornerRadius
    }

    contentItem: ListView {
      id: choices
      clip: true
      implicitHeight: contentHeight
      model: root.popup.visible ? root.delegateModel : null
      currentIndex: root.highlightedIndex
      spacing: Style.spacing.labelGap
      boundsBehavior: Flickable.StopAtBounds
      ScrollIndicator.vertical: ScrollIndicator {}
    }
  }
}
