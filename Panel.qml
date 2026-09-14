import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "axelfontaine.logitech-unifying"
  ipcTarget: "axelfontaine.logitech-unifying"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string helperPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/axelfontaine.logitech-unifying/bin/hidpp-receiver"
  readonly property string fixPermsPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/axelfontaine.logitech-unifying/bin/fix-udev-permissions"
  property bool fixingPermissions: false

  property var receivers: []
  readonly property var receiver: receivers.length > 0 ? receivers[0] : null
  readonly property bool anyReceiver: receiver !== null

  // Hide the bar icon entirely when no Unifying receiver is detected,
  // rather than just dimming it.
  visible: anyReceiver
  // ...and close the popout too, if it happened to be open when the
  // receiver was unplugged — otherwise it's left showing a stale device
  // list with no way to reach it from the (now hidden) bar icon.
  onAnyReceiverChanged: if (!anyReceiver && root.opened) root.close()

  property bool isPairing: false
  property int pairingSecondsLeft: 0
  // Device count when the lock was opened, so a poll that sees a new
  // device join can close the lock right away instead of waiting out the
  // rest of the countdown.
  property int pairingStartDeviceCount: -1
  // { slot, name } while the unpair confirmation is open, else null
  property var pendingUnpair: null

  // Mouse-driven row-hover state for the device list, mirroring the
  // Bluetooth panel's DeviceRow/actionFocused pattern: only one row's
  // highlight is ever shown at a time, and when the pointer is over a
  // row's unpair button, actionFocused hands the highlight to the button
  // instead of the row it sits in — otherwise the two overlapping
  // MouseAreas fight over the hover visuals and flicker.
  property bool cursorActive: false
  // -1 means the "Pair new device" header button; 0+ indexes a device row.
  property int selectedIndex: -1
  property bool actionFocused: false
  readonly property bool headerHasCursor: cursorActive && selectedIndex === -1

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function fixPermissions() {
    if (root.fixingPermissions) return
    root.fixingPermissions = true
    fixPermsProc.running = true
  }

  // Keyboard/mouse cursor helpers, mirroring the Bluetooth panel's
  // moveCursor/moveCursorH/activateCursor/deleteSelected — j/k (or arrows)
  // walk the header button and device rows, h/l (or arrows) hand focus
  // between a row and its unpair button, Enter activates whatever has
  // focus, and 'x' unpairs directly.
  function setHeaderCursor() {
    root.cursorActive = true
    root.selectedIndex = -1
    root.actionFocused = false
  }

  function moveCursor(delta) {
    var devices = (root.receiver && root.receiver.devices) ? root.receiver.devices : []
    var count = devices.length
    if (root.selectedIndex < 0) {
      if (delta > 0 && count > 0) { root.selectedIndex = 0; root.actionFocused = false }
      return
    }
    if (count === 0) { root.selectedIndex = -1; root.actionFocused = false; return }
    if (delta > 0) {
      if (root.selectedIndex < count - 1) { root.selectedIndex += 1; root.actionFocused = false }
    } else if (root.selectedIndex > 0) {
      root.selectedIndex -= 1; root.actionFocused = false
    } else {
      root.selectedIndex = -1; root.actionFocused = false
    }
  }

  function moveCursorH(delta) {
    if (!root.cursorActive) { root.cursorActive = true; return }
    if (root.selectedIndex < 0) return
    if (delta > 0) root.actionFocused = true
    else if (delta < 0) root.actionFocused = false
  }

  function activateCursor() {
    if (root.selectedIndex < 0) {
      if (root.isPairing) root.stopPairing(); else root.startPairing()
      return
    }
    if (root.actionFocused) root.deleteSelected()
  }

  function deleteSelected() {
    if (root.selectedIndex < 0) return
    var devices = (root.receiver && root.receiver.devices) ? root.receiver.devices : []
    root.requestUnpair(devices[root.selectedIndex])
  }

  function startPairing() {
    if (!root.receiver) return
    root.isPairing = true
    root.pairingSecondsLeft = 30
    root.pairingStartDeviceCount = (root.receiver.devices || []).length
    Quickshell.execDetached([root.helperPath, "pair-start", root.receiver.id, "--timeout", "30"])
    pairingCountdown.restart()
  }

  function stopPairing() {
    if (!root.isPairing || !root.receiver) return
    Quickshell.execDetached([root.helperPath, "pair-stop", root.receiver.id])
    root.isPairing = false
    root.pairingSecondsLeft = 0
    root.pairingStartDeviceCount = -1
    pairingCountdown.stop()
    refreshSoon.restart()
  }

  // Called whenever a fresh `list` result comes in. If the receiver now has
  // more devices than it did when the lock opened, the new device joined —
  // close the lock instead of leaving it open for the rest of the
  // countdown.
  function checkPairingJoined() {
    if (!root.isPairing || !root.receiver) return
    if ((root.receiver.devices || []).length > root.pairingStartDeviceCount) root.stopPairing()
  }

  function requestUnpair(device) {
    if (!device) return
    root.pendingUnpair = { slot: device.slot, name: device.name }
  }

  function confirmUnpair() {
    var pending = root.pendingUnpair
    root.pendingUnpair = null
    if (!pending || !root.receiver) return
    Quickshell.execDetached([root.helperPath, "unpair", root.receiver.id, String(pending.slot)])
    refreshSoon.restart()
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
      actionFocused = false
      cursorActive = false
      var devices = (root.receiver && root.receiver.devices) ? root.receiver.devices : []
      selectedIndex = devices.length > 0 ? 0 : -1
    }
  }

  // Route keyboard focus between the normal j/k-driven cursor and the
  // unpair confirmation dialog while it's open, so Escape/Enter/arrows
  // work on the dialog's Cancel/Unpair choice instead of falling through
  // to the panel's own navigation underneath it.
  onPendingUnpairChanged: {
    if (pendingUnpair !== null) {
      dialogKeys.forceActiveFocus()
    } else {
      keyCatcher.forceActiveFocus()
      // Otherwise this stays stuck true from the row's unpair button that
      // opened the dialog, and every row's hasCursor (rowSelected &&
      // !actionFocused) goes permanently false — nothing ever shows as
      // focused again, even though keys are still reaching keyCatcher.
      root.actionFocused = false
    }
  }

  Process {
    id: listProc
    command: [root.helperPath, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.receivers = Model.parseReceivers(text)
        root.checkPairingJoined()
        // A device dropping out of the list (unpaired, or the list simply
        // shrank on refresh) can leave selectedIndex pointing past the new
        // end — clamp it back onto a real row instead of leaving keyboard
        // nav pointed at nothing.
        var deviceCount = (root.receiver && root.receiver.devices) ? root.receiver.devices.length : 0
        if (root.selectedIndex >= deviceCount) root.selectedIndex = deviceCount - 1
      }
    }
  }

  // Rewrites the udev rule granting this receiver's hidraw node access and
  // reloads udev, via a polkit prompt (no terminal needed). Exits either way
  // — accepted, canceled, or failed — so refresh() always runs after to
  // reflect whatever the actual permission state ends up being.
  Process {
    id: fixPermsProc
    command: ["pkexec", root.fixPermsPath]
    onExited: {
      root.fixingPermissions = false
      root.refresh()
    }
  }

  Timer {
    // Always runs — not just while the panel is open — so the bar icon
    // (which hides itself when no receiver is present, and shows battery
    // state on hover-free glance) reflects reality without the user having
    // to open the popout first. Polls faster while the popout is open or a
    // pairing lock is active (also kept alive through the popout getting
    // dismissed mid-pairing) for snappier feedback there.
    interval: (root.opened || root.isPairing) ? 4000 : 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // A short extra refresh a couple seconds after an action, so the list
  // reflects a pair/unpair without waiting for the next regular poll.
  Timer {
    id: refreshSoon
    interval: 2000
    onTriggered: root.refresh()
  }

  Timer {
    id: pairingCountdown
    interval: 1000
    repeat: true
    onTriggered: {
      root.pairingSecondsLeft -= 1
      if (root.pairingSecondsLeft <= 0) root.stopPairing()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: unifyingBarIconComponent
    onPressed: root.toggle()
  }

  Component {
    id: unifyingBarIconComponent
    Item {
      UnifyingIcon {
        anchors.centerIn: parent
        iconSize: Style.bar.iconFont * 0.85
        color: button.foreground
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(420))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.pendingUnpair !== null
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.moveCursorH(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onDeleteRequested: if (root.cursorActive) root.deleteSelected()

      // PanelKeyCatcher only wires 'x' to deleteRequested, and it's the
      // shared component (can't be edited to add Delete there). A window-
      // level Shortcut works alongside it without fighting over which item
      // holds keyboard focus.
      Shortcut {
        sequence: "Delete"
        enabled: root.opened && root.cursorActive && root.pendingUnpair === null
        onActivated: root.deleteSelected()
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(titleRow.implicitHeight, pairBtn.implicitHeight)

          Row {
            id: titleRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            UnifyingIcon {
              anchors.verticalCenter: parent.verticalCenter
              iconSize: Style.font.heading
              color: root.bar.foreground
            }

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Logitech Unifying Receiver"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
          }

          Button {
            id: pairBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            iconText: root.isPairing ? "" : "󰐕"
            text: root.isPairing ? ("Stop (" + root.pairingSecondsLeft + "s)") : ""
            tooltipText: root.isPairing ? "" : "Pair new device"
            hasCursor: root.headerHasCursor
            onHovered: function(isHovered) { if (isHovered) root.setHeaderCursor() }
            onClicked: root.isPairing ? root.stopPairing() : root.startPairing()
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Text {
          visible: root.isPairing
          textFormat: Text.PlainText
          text: "Turn the new device off, then on, to put it in pairing mode"
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Text {
          visible: !!(root.receiver && root.receiver.error)
          textFormat: Text.PlainText
          text: root.receiver ? (root.receiver.error || "") : ""
          color: Color.urgent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Button {
          visible: !!(root.receiver && root.receiver.error && Model.isPermissionError(root.receiver.error))
          bordered: true
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          enabled: !root.fixingPermissions
          text: root.fixingPermissions ? "Fixing…" : "Fix permissions"
          onClicked: root.fixPermissions()
        }

        Text {
          visible: root.receiver && !root.receiver.error && (root.receiver.devices || []).length === 0
          textFormat: Text.PlainText
          text: "No paired devices"
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        PanelSectionHeader {
          visible: root.receiver && !root.receiver.error && (root.receiver.devices || []).length > 0
          text: "PAIRED"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Column {
          id: deviceList
          width: column.width
          // Matches the Dropbox panel's file-row spacing — tighter than the
          // outer column's spacing, which is meant for separating whole
          // sections rather than same-list rows.
          spacing: Style.space(6)

          Repeater {
            model: root.receiver ? (root.receiver.devices || []) : []
            delegate: CursorSurface {
              id: deviceRow
              required property var modelData
              required property int index
              width: column.width
              implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

              readonly property var device: modelData
              // Only one row's highlight is shown at a time (root.selectedIndex),
              // and root.actionFocused hands it from the row to the unpair
              // button when the pointer is over the button instead — same
              // pattern as the Bluetooth panel's DeviceRow/forgetBtn, needed
              // because the button sits inside the row's own hover area and
              // the two would otherwise fight over the hover visuals.
              readonly property bool rowSelected: root.cursorActive && root.selectedIndex === index

              foreground: root.bar.foreground
              hasCursor: rowSelected && !root.actionFocused

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) {
                  root.cursorActive = true
                  root.selectedIndex = deviceRow.index
                  root.actionFocused = false
                }
              }

              Item {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                implicitHeight: Math.max(kindIcon.implicitHeight, info.implicitHeight, unpairBtn.implicitHeight)

                Text {
                  id: kindIcon
                  textFormat: Text.PlainText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.kindIcon(deviceRow.device.kind)
                  color: deviceRow.device.online ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.8)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.icon
                }

                Column {
                  id: info
                  anchors.left: kindIcon.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: unpairBtn.visible ? unpairBtn.left : parent.right
                  anchors.rightMargin: unpairBtn.visible ? Style.space(8) : 0
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    textFormat: Text.PlainText
                    text: Model.deviceName(deviceRow.device)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    width: parent.width
                  }
                  Row {
                    spacing: Style.space(3)
                    visible: statusLabel.text !== ""

                    Text {
                      textFormat: Text.PlainText
                      visible: text !== ""
                      text: Model.batteryIcon(deviceRow.device)
                      color: Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Text {
                      id: statusLabel
                      textFormat: Text.PlainText
                      text: Model.deviceStatusLabel(deviceRow.device)
                      color: Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }

                PanelActionButton {
                  id: unpairBtn
                  visible: rowMouse.containsMouse || deviceRow.rowSelected
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "󰅙"
                  tooltipText: "Unpair"
                  foreground: root.bar.foreground
                  hoverColor: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  hasCursor: deviceRow.rowSelected && root.actionFocused
                  onHovered: function(isHovered) {
                    if (!isHovered) {
                      if (rowMouse.containsMouse) root.actionFocused = false
                      return
                    }
                    root.cursorActive = true
                    root.selectedIndex = deviceRow.index
                    root.actionFocused = true
                  }
                  onClicked: root.requestUnpair(deviceRow.device)
                }
              }
            }
          }
        }
      }
    }

    ConfirmDialog {
      id: unpairDialog
      anchors.fill: parent
      opened: root.pendingUnpair !== null
      message: root.pendingUnpair ? ("Unpair \"" + root.pendingUnpair.name + "\"? You'll need to re-pair it by hand afterward.") : ""
      cancelText: "Cancel"
      confirmText: "Unpair"
      onCanceled: root.pendingUnpair = null
      onConfirmed: root.confirmUnpair()
    }

    // Takes over keyboard focus from keyCatcher while the dialog above is
    // open (see onPendingUnpairChanged), so Escape/arrows/Enter drive its
    // Cancel/Unpair choice instead of the panel's row cursor underneath it.
    Item {
      id: dialogKeys
      anchors.fill: parent
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (unpairDialog.handleKey(event)) event.accepted = true
      }
    }
  }
}
