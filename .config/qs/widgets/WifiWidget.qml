import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import "../" as RootDir

Item {
  id: wifiWidget

  readonly property real hPadding: 16

  implicitHeight: expanded ? 500 : 32
  implicitWidth: expanded ? 300 : label.implicitWidth + hPadding * 2

  property string connectionName: ""
  property bool expanded: false

  // network state
  property var networks: []
  property var savedSsids: []
  property bool scanning: false
  property string pendingSsid: ""
  property string statusText: ""

  readonly property real collapsedHeight: 32
  readonly property real baseRadius: collapsedHeight / 2
  readonly property real radiusExponent: 0.4

  readonly property real cornerRadius: Math.min(
    height / 2,
    baseRadius * Math.pow(Math.max(height, collapsedHeight) / collapsedHeight, radiusExponent)
  )

  readonly property color fg: "#F2E8D5"
  readonly property color fgDim: "#8a9aa5"
  readonly property color rowBg: "#12293a"
  readonly property color accent: "#2d6a8f"
  readonly property string fontFamily: "Monaspace Argon Frozen"

  Behavior on implicitHeight {
    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  Behavior on implicitWidth {
    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  onExpandedChanged: {
    if (expanded) {
      refreshSaved();
      scan();
    } else {
      pendingSsid = "";
      statusText = "";
    }
  }

  function splitTerse(line) {
    let fields = [], cur = "";
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === "\\" && i + 1 < line.length) {
        cur += line[++i];
      } else if (c === ":") {
        fields.push(cur);
        cur = "";
      } else {
        cur += c;
      }
    }
    fields.push(cur);
    return fields;
  }

  function parseNetworks(text) {
    const best = {};
    for (const line of text.split("\n")) {
      if (!line.trim()) continue;
      const [inUse, ssid, signal, security] = splitTerse(line);
      if (!ssid) continue;
      const entry = {
        ssid: ssid,
        signal: parseInt(signal) || 0,
        secure: security !== "" && security !== "--",
        active: inUse === "*",
        saved: savedSsids.indexOf(ssid) !== -1
      };
      const prev = best[ssid];
      if (!prev || entry.active || (!prev.active && entry.signal > prev.signal)) {
        best[ssid] = entry;
      }
    }
    const list = Object.values(best);
    list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
    networks = list;
  }

  function refreshSaved() {
    savedProc.running = true;
  }

  function scan() {
    scanning = true;
    scanProc.running = true;
  }

  function connectTo(net) {
    if (net.active) return;
    if (net.secure && !net.saved) {
      pendingSsid = net.ssid;
      passwordField.text = "";
      passwordField.forceActiveFocus();
      return;
    }
    runConnect(["nmcli", "connection", "up", "id", net.ssid], net.ssid);
  }

  function submitPassword() {
    if (pendingSsid === "") return;
    const ssid = pendingSsid;
    runConnect(["nmcli", "device", "wifi", "connect", ssid, "password", passwordField.text], ssid);
    passwordField.text = "";
    pendingSsid = "";
  }

  function runConnect(cmd, ssid) {
    statusText = "Connecting to " + ssid + "…";
    connectProc.command = cmd;
    connectProc.running = true;
  }

  Process {
    id: netProc
    command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active | grep -E '802-11-wireless|802-3-ethernet' | head -n1 | cut -d: -f1"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: wifiWidget.connectionName = text.trim()
    }
  }

  Process {
    id: savedProc
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const names = [];
        for (const line of text.split("\n")) {
          const f = wifiWidget.splitTerse(line);
          if (f[1] === "802-11-wireless") names.push(f[0]);
        }
        wifiWidget.savedSsids = names;
      }
    }
  }

  Process {
    id: scanProc
    command: ["sh", "-c", "nmcli device wifi rescan 2>/dev/null; sleep 1; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list"]
    stdout: StdioCollector {
      onStreamFinished: {
        wifiWidget.parseNetworks(text);
        wifiWidget.scanning = false;
      }
    }
  }

  Process {
    id: connectProc
    stderr: StdioCollector {
      id: connectErr
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        wifiWidget.statusText = "";
      } else {
        wifiWidget.statusText = connectErr.text.trim() || "Connection failed";
      }
      netProc.running = true;
      wifiWidget.refreshSaved();
      wifiWidget.scan();
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: netProc.running = true
  }

  HyprlandFocusGrab {
    windows: [ wifiWidget.QsWindow.window ]
    active: wifiWidget.expanded
    onCleared: wifiWidget.expanded = false
  }

  component PillButton: Rectangle {
    id: btn
    property string text: ""
    signal clicked()

    implicitWidth: btnLabel.implicitWidth + 20
    implicitHeight: 24
    radius: height / 2
    color: btnArea.containsMouse ? wifiWidget.accent : wifiWidget.rowBg

    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      id: btnLabel
      anchors.centerIn: parent
      text: btn.text
      color: wifiWidget.fg
      font.pixelSize: 12
      font.family: wifiWidget.fontFamily
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  Rectangle {
    id: bg
    anchors.fill: parent

    color: "#0b1b26"

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: wifiWidget.cornerRadius
    bottomRightRadius: wifiWidget.cornerRadius

    Behavior on border.color {
      ColorAnimation { duration: 100 }
    }

    MouseArea {
      anchors.fill: parent
      enabled: !wifiWidget.expanded
      cursorShape: Qt.PointingHandCursor
      onClicked: wifiWidget.expanded = true
    }

    Text {
      id: label
      anchors.centerIn: parent
      visible: !wifiWidget.expanded
      color: wifiWidget.fg
      font.pixelSize: 14
      font.family: wifiWidget.fontFamily
      text: wifiWidget.connectionName || "Disconnected"
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 14
      anchors.topMargin: 18
      spacing: 10

      opacity: wifiWidget.expanded ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 150 } }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          Layout.fillWidth: true
          text: "Wi-Fi"
          color: wifiWidget.fg
          font.pixelSize: 16
          font.bold: true
          font.family: wifiWidget.fontFamily
        }

        PillButton {
          text: wifiWidget.scanning ? "Scanning…" : "Scan"
          onClicked: if (!wifiWidget.scanning) wifiWidget.scan()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        visible: wifiWidget.pendingSsid !== ""
        radius: 10
        color: wifiWidget.rowBg

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 2

          Text {
            text: "Password for " + wifiWidget.pendingSsid
            color: wifiWidget.fgDim
            font.pixelSize: 11
            font.family: wifiWidget.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          TextInput {
            id: passwordField
            Layout.fillWidth: true
            echoMode: TextInput.Password
            color: wifiWidget.fg
            font.pixelSize: 13
            font.family: wifiWidget.fontFamily
            clip: true
            onAccepted: wifiWidget.submitPassword()
            Keys.onEscapePressed: wifiWidget.pendingSsid = ""
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: wifiWidget.statusText !== ""
        text: wifiWidget.statusText
        color: wifiWidget.fgDim
        font.pixelSize: 11
        font.family: wifiWidget.fontFamily
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: wifiWidget.networks

        delegate: Rectangle {
          required property var modelData

          width: ListView.view.width
          height: 38
          radius: 10
          color: modelData.active ? wifiWidget.accent
          : rowArea.containsMouse ? "#1a3a50" : wifiWidget.rowBg

          Behavior on color { ColorAnimation { duration: 100 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
              Layout.fillWidth: true
              text: modelData.ssid
              color: wifiWidget.fg
              font.pixelSize: 13
              font.family: wifiWidget.fontFamily
              elide: Text.ElideRight
            }

            Text {
              visible: modelData.secure
              text: modelData.saved ? "saved" : "locked"
              color: wifiWidget.fgDim
              font.pixelSize: 10
              font.family: wifiWidget.fontFamily
            }

            Text {
              text: modelData.signal + "%"
              color: wifiWidget.fgDim
              font.pixelSize: 11
              font.family: wifiWidget.fontFamily
            }
          }

          MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wifiWidget.connectTo(modelData)
          }
        }

        Text {
          anchors.centerIn: parent
          visible: wifiWidget.networks.length === 0 && !wifiWidget.scanning
          text: "No networks found"
          color: wifiWidget.fgDim
          font.pixelSize: 12
          font.family: wifiWidget.fontFamily
        }
      }
    }
  }

  RootDir.ConcaveCorner {
    radius: cornerRadius
    color: bg.color
    mirrored: true
    x: -width
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: cornerRadius
    color: bg.color
    x: wifiWidget.width
    y: 0
  }
}
