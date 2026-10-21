import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland

import "../" as RootDir
import "../windows"

Item {
  id: musicWidget

  implicitHeight: expanded ? 300 : 32
  
  property real bodyWidth: 420

  implicitWidth: bodyWidth + cornerRadius * 2

  property var lastPlaying: null
  property var pinned: null

  property bool expanded: false

  readonly property bool isPlaying: player !== null && player.playbackState === MprisPlaybackState.Playing
  readonly property real progress: (player && player.length > 0) ? Math.min(1, player.position / player.length) : 0

  readonly property real collapsedHeight: 32
  readonly property real baseRadius: collapsedHeight / 2
  readonly property real radiusExponent: 0.4

  readonly property real cornerRadius: Math.min(
    height / 2,
    baseRadius * Math.pow(Math.max(height, collapsedHeight) / collapsedHeight, radiusExponent)
  )

  Behavior on implicitHeight {
    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  property var player: {
    const list = Mpris.players.values;
    if (pinned && list.includes(pinned)) return pinned;

    const playing = list.find(p => p.playbackState === MprisPlaybackState.Playing);
    if (playing) return playing;

    if (lastPlaying && list.includes(lastPlaying)) return lastPlaying;

    return list.find(p => p.identity === "Spotify") ?? list[0] ?? null;
  }

  Instantiator {
    model: Mpris.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onPlaybackStateChanged() {
        if (modelData.playbackState === MprisPlaybackState.Playing)
        musicWidget.lastPlaying = modelData;
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: musicWidget.isPlaying
    onTriggered: musicWidget.player?.positionChanged()
  }

  Rectangle {
    id: bg
    x: musicWidget.cornerRadius
    width: musicWidget.bodyWidth
    height: parent.height
    color: RootDir.Theme.bg

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: musicWidget.cornerRadius
    bottomRightRadius: musicWidget.cornerRadius

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 32
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      spacing: 10

      Text {
        id: playerLabel
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: 90
        text: musicWidget.player
        ? musicWidget.player.identity + (musicWidget.pinned ? " 📌" : "")
        : "No player"
        elide: Text.ElideRight
        font.family: RootDir.Fonts.text
        font.pixelSize: 12
        color: RootDir.Theme.fgMuted

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onClicked: (mouse) => {
            const list = Mpris.players.values;
            if (mouse.button === Qt.RightButton || list.length === 0) {
              musicWidget.pinned = null;
              return;
            }
            const i = list.indexOf(musicWidget.player);
            musicWidget.pinned = list[(i + 1) % list.length];
          }
        }
      }

      // title – artist
      Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: {
          const p = musicWidget.player;
          if (!p || p.trackTitle === "") return "Nothing playing";
          return p.trackArtist !== "" ? p.trackTitle + "  -  " + p.trackArtist : p.trackTitle;
        }
        elide: Text.ElideRight
        font.family: RootDir.Fonts.text
        font.pixelSize: 14
        color: RootDir.Theme.fg

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor

          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
              musicWidget.expanded = !musicWidget.expanded
              return;
            }
          }

        }
      }

      Repeater {
        model: [
        { glyph: "⏮", action: "prev" },
        { glyph: "", action: "toggle" },
        { glyph: "⏭", action: "next" }
        ]

        delegate: Text {
          required property var modelData

          Layout.alignment: Qt.AlignVCenter
          text: modelData.action === "toggle"
          ? (musicWidget.isPlaying ? "⏸" : "▶")
          : modelData.glyph
          font.pixelSize: 15
          font.family: RootDir.Fonts.icon
          color: btnArea.containsMouse ? RootDir.Theme.accentHover : RootDir.Theme.fg
          scale: btnArea.containsMouse ? 1.15 : 1

          Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
          }

          MouseArea {
            id: btnArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const p = musicWidget.player;
              if (!p) return;
              if (modelData.action === "toggle") p.togglePlaying();
              else if (modelData.action === "next") p.next();
              else if (p.position > 3) p.position = 0;
              else p.previous();
            }
          }
        }
      }
    }

    // progress bar
    Rectangle {
      x: musicWidget.cornerRadius
      y: bg.height - height - 2
      height: 2
      radius: 1
      width: (bg.width - musicWidget.cornerRadius * 2) * musicWidget.progress
      color: RootDir.Theme.fg
      opacity: 0.6

      Behavior on width {
        NumberAnimation { duration: 1000; easing.type: Easing.Linear }
      }
    }
  }

  RootDir.ConcaveCorner {
    radius: musicWidget.cornerRadius
    color: bg.color
    mirrored: true
    x: 0
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: musicWidget.cornerRadius
    color: bg.color
    x: musicWidget.width - musicWidget.cornerRadius
    y: 0
  }

  HyprlandFocusGrab {
    windows: [ musicWidget.QsWindow.window ]
    active: musicWidget.expanded
    onCleared: musicWidget.expanded = false
  }
}
