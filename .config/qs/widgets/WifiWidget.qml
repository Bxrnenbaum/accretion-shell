import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import "../" as RootDir

Item {
  id: wifiWidget

  readonly property real hPadding: 16

  property real bodyWidth: expanded ? 240 : label.implicitWidth + hPadding * 2

  implicitHeight: expanded ? 300 : 32
  implicitWidth: bodyWidth + cornerRadius * 2

  property string connectionName: ""
  property bool expanded: false

  // network state
  property var networks: []        // [{ssid, signal, secure, enterprise, active, saved}]
  property var savedSsids: []
  property bool scanning: false
  property string pendingSsid: ""
  property bool pendingEnterprise: false
  property string eapMethod: "peap"   // "peap" (+mschapv2) or "ttls" (+pap)
  property string statusText: ""

  // remembered for the connect error handler
  property string lastSsid: ""
  property bool lastEnterprise: false

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

  Behavior on bodyWidth {
    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  onExpandedChanged: {
    if (expanded) {
      refreshSaved();
      scan();
    } else {
      clearPrompt();
      statusText = "";
    }
  }

  function clearPrompt() {
    pendingSsid = "";
    pendingEnterprise = false;
    usernameField.text = "";
    passwordField.text = "";
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
        enterprise: security.indexOf("802.1X") !== -1,
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

  function promptFor(ssid, enterprise) {
    pendingSsid = ssid;
    pendingEnterprise = enterprise;
    usernameField.text = "";
    passwordField.text = "";
    if (enterprise) usernameField.forceActiveFocus();
    else passwordField.forceActiveFocus();
  }

  function connectTo(net) {
    if (net.active) return;

    if (net.saved) {
      runConnect(["nmcli", "connection", "up", "id", net.ssid], net.ssid, net.enterprise);
    } else if (net.enterprise) {
      promptFor(net.ssid, true);
    } else if (net.secure) {
      promptFor(net.ssid, false);
    } else {
      runConnect(["nmcli", "device", "wifi", "connect", net.ssid], net.ssid, false);
    }
  }

  function submitPrompt() {
    if (pendingSsid === "") return;
    const ssid = pendingSsid;

    if (pendingEnterprise) {
      if (usernameField.text === "" || passwordField.text === "") return;
      const phase2 = eapMethod === "ttls" ? "pap" : "mschapv2";
      const script = `
        if nmcli connection show id "$1" >/dev/null 2>&1; then
          nmcli connection modify id "$1" 802-1x.identity "$4" 802-1x.password "$5" \
            802-1x.password-flags 0 connection.autoconnect yes
        else
          nmcli connection add type wifi con-name "$1" ssid "$1" \
            wifi-sec.key-mgmt wpa-eap 802-1x.eap "$2" 802-1x.phase2-auth "$3" \
            802-1x.identity "$4" 802-1x.password "$5" 802-1x.password-flags 0 \
            connection.autoconnect yes
        fi && nmcli connection up id "$1"
      `;
      runConnect(["sh", "-c", script, "sh", ssid, eapMethod, phase2,
                  usernameField.text, passwordField.text], ssid, true);
    } else {
      runConnect(["nmcli", "device", "wifi", "connect", ssid, "password", passwordField.text], ssid, false);
    }
    clearPrompt();
  }

  function runConnect(cmd, ssid, enterprise) {
    lastSsid = ssid;
    lastEnterprise = enterprise;
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
        portalProc.running = true;
      } else {
        const err = connectErr.text.trim();
        wifiWidget.statusText = err || "Connection failed";
        if (wifiWidget.lastEnterprise && /secret|supplicant|auth|password|identity/i.test(err)) {
          wifiWidget.promptFor(wifiWidget.lastSsid, true);
        }
      }
      netProc.running = true;
      wifiWidget.refreshSaved();
      wifiWidget.scan();
    }
  }

  Process {
    id: portalProc
    command: ["sh", "-c", "sleep 2; [ \"$(nmcli networking connectivity check)\" = portal ] && xdg-open http://neverssl.com"]
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
    property color fg: "white"
    property color baseColor: "#12293a"
    property color hoverColor: "#2d6a8f"
    property string fontFamily: ""
    signal clicked()

    implicitWidth: btnLabel.implicitWidth + 20
    implicitHeight: 24
    radius: height / 2
    color: btnArea.containsMouse ? hoverColor : baseColor

    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      id: btnLabel
      anchors.centerIn: parent
      text: btn.text
      color: btn.fg
      font.pixelSize: 12
      font.family: btn.fontFamily
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
    x: wifiWidget.cornerRadius 
    width: wifiWidget.bodyWidth
    height: parent.height

    color: "#0b1b26"

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: wifiWidget.cornerRadius
    bottomRightRadius: wifiWidget.cornerRadius

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
          fg: wifiWidget.fg
          baseColor: wifiWidget.rowBg
          hoverColor: wifiWidget.accent
          fontFamily: wifiWidget.fontFamily
          onClicked: if (!wifiWidget.scanning) wifiWidget.scan()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: promptCol.implicitHeight + 16
        visible: wifiWidget.pendingSsid !== ""
        radius: 10
        color: wifiWidget.rowBg

        ColumnLayout {
          id: promptCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 8
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              Layout.fillWidth: true
              text: (wifiWidget.pendingEnterprise ? "Sign in to " : "Password for ") + wifiWidget.pendingSsid
              color: wifiWidget.fgDim
              font.pixelSize: 11
              font.family: wifiWidget.fontFamily
              elide: Text.ElideRight
            }

            PillButton {
              visible: wifiWidget.pendingEnterprise
              text: wifiWidget.eapMethod === "ttls" ? "TTLS/PAP" : "PEAP/MSCHAPv2"
              fg: wifiWidget.fg
              baseColor: "#0b1b26"
              hoverColor: wifiWidget.accent
              fontFamily: wifiWidget.fontFamily
              implicitHeight: 20
              onClicked: wifiWidget.eapMethod = wifiWidget.eapMethod === "peap" ? "ttls" : "peap"
            }
          }

          TextInput {
            id: usernameField
            Layout.fillWidth: true
            visible: wifiWidget.pendingEnterprise
            color: wifiWidget.fg
            font.pixelSize: 13
            font.family: wifiWidget.fontFamily
            clip: true
            KeyNavigation.tab: passwordField
            onAccepted: passwordField.forceActiveFocus()
            Keys.onEscapePressed: wifiWidget.clearPrompt()

            Text {
              visible: usernameField.text === ""
              text: "Username"
              color: wifiWidget.fgDim
              font: usernameField.font
            }
          }

          TextInput {
            id: passwordField
            Layout.fillWidth: true
            echoMode: TextInput.Password
            color: wifiWidget.fg
            font.pixelSize: 13
            font.family: wifiWidget.fontFamily
            clip: true
            onAccepted: wifiWidget.submitPrompt()
            Keys.onEscapePressed: wifiWidget.clearPrompt()

            Text {
              visible: passwordField.text === "" && wifiWidget.pendingEnterprise
              text: "Password"
              color: wifiWidget.fgDim
              font: passwordField.font
            }
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
              visible: modelData.secure || modelData.saved
              text: modelData.saved ? "saved" : modelData.enterprise ? "802.1X" : "locked"
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
    radius: wifiWidget.cornerRadius
    color: bg.color
    mirrored: true
    x: 0
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: wifiWidget.cornerRadius
    color: bg.color
    x: wifiWidget.width - wifiWidget.cornerRadius
    y: 0
  }
}
