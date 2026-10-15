import QtQuick

TextInput {
  id: root

  property string placeholderText: ""
  property var history: []
  property var future: []
  signal edited()
  signal pasteRequested(bool primary)
  signal navigated(int key)

  // Never make this writable: Qt's canPaste checks fetch the clipboard before a paste gesture.
  readOnly: true
  maximumLength: 128
  selectByMouse: true
  activeFocusOnTab: true
  cursorVisible: activeFocus
  clip: true

  function replace(addition) {
    if (/[\u0000-\u001f\u007f-\u009f]/.test(addition)) return false
    var start = selectionStart
    var end = selectionEnd
    var next = text.slice(0, start) + addition + text.slice(end)
    if (next.length > maximumLength) return false
    history = history.slice(-31).concat([{ text: text, cursor: cursorPosition }])
    future = []
    text = next
    cursorPosition = start + addition.length
    edited()
    return true
  }

  function erase(backward, word) {
    if (selectionStart === selectionEnd) {
      var start = cursorPosition
      var end = cursorPosition
      if (backward) {
        start = word ? text.slice(0, start).replace(/\S*\s*$/, "").length : Math.max(0, start - 1)
        if (start > 0 && /[\udc00-\udfff]/.test(text.charAt(start))) start--
      } else {
        end = word ? end + text.slice(end).match(/^\s*\S*/)[0].length : Math.min(text.length, end + 1)
        if (end < text.length && /[\udc00-\udfff]/.test(text.charAt(end))) end++
      }
      select(start, end)
    }
    replace("")
  }

  function restore(redo) {
    var stack = redo ? future : history
    if (stack.length === 0) return
    var previous = stack[stack.length - 1]
    var current = { text: text, cursor: cursorPosition }
    if (redo) {
      future = stack.slice(0, -1)
      history = history.concat([current])
    } else {
      history = stack.slice(0, -1)
      future = future.concat([current])
    }
    text = previous.text
    cursorPosition = previous.cursor
    edited()
  }

  Keys.onShortcutOverride: function(event) {
    if (event.matches(StandardKey.Paste) || event.matches(StandardKey.Cut)
        || event.matches(StandardKey.Undo) || event.matches(StandardKey.Redo)) event.accepted = true
  }
  Keys.onPressed: function(event) {
    if (event.matches(StandardKey.Paste)) pasteRequested(false)
    else if (event.matches(StandardKey.Cut)) { copy(); replace("") }
    else if (event.matches(StandardKey.Undo)) restore(false)
    else if (event.matches(StandardKey.Redo)) restore(true)
    else if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape].indexOf(event.key) !== -1)
      navigated(event.key)
    else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
      erase(event.key === Qt.Key_Backspace, !!(event.modifiers & Qt.ControlModifier))
    else if (event.text && !(event.modifiers & Qt.MetaModifier)
        && (!(event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.AltModifier))
        && !/[\u0000-\u001f\u007f-\u009f]/.test(event.text)) replace(event.text)
    else { event.accepted = false; return }
    event.accepted = true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onClicked: function(mouse) {
      root.forceActiveFocus()
      root.cursorPosition = root.positionAt(mouse.x, mouse.y)
      root.pasteRequested(true)
    }
  }

  Text {
    visible: root.text.length === 0
    anchors.left: parent.left
    anchors.leftMargin: root.leftPadding
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.placeholderText
    font: root.font
    color: root.color
    opacity: 0.5
  }
}
