import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

import "../" as RootDir
import "../windows"

Item {
  id: musicWidget

  implicitHeight: expanded ? 160 : 32

  property real bodyWidth: expanded ? 500 : 420

  Behavior on bodyWidth {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  implicitWidth: bodyWidth + cornerRadius * 2

  property var lastPlaying: null
  property var pinned: null

  property bool expanded: false

  readonly property bool isPlaying: player !== null && player.playbackState === MprisPlaybackState.Playing
  readonly property real progress: (player && player.length > 0)
  ? Math.min(1, player.position / player.length)
  : 0
  property var cavaLevels: []

  onIsPlayingChanged: {
    if (!isPlaying)
    cavaLevels = [];
  }

  readonly property real collapsedHeight: 32
  readonly property real baseRadius: collapsedHeight / 2
  readonly property real radiusExponent: 0.4

  readonly property real cornerRadius: Math.min(
    height / 2,
    baseRadius * Math.pow(
      Math.max(height, collapsedHeight) / collapsedHeight,
      radiusExponent
    )
  )

  Behavior on implicitHeight {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  property var player: {
    const list = Mpris.players.values;

    if (pinned && list.includes(pinned))
    return pinned;

    const playing = list.find(
      p => p.playbackState === MprisPlaybackState.Playing
    );

    if (playing)
    return playing;

    if (lastPlaying && list.includes(lastPlaying))
    return lastPlaying;

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

    onTriggered: {
      if (musicWidget.player)
      musicWidget.player.positionChanged();
    }
  }

  Process {
    running: musicWidget.expanded && musicWidget.isPlaying
    command: ["cava", "-p", Quickshell.shellPath("cava.conf")]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => {
        const values = data.trim().split(";").filter(value => value.length > 0).map(
          value => Math.max(0, Math.min(1, Number(value) / 100))
        );

        if (values.length > 0)
        musicWidget.cavaLevels = values;
      }
    }
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

    Loader {
      id: collapsedLoader

      anchors.fill: parent
      sourceComponent: collapsedContent

      opacity: musicWidget.expanded ? 0 : 1
      scale: musicWidget.expanded ? 0.985 : 1
      enabled: !musicWidget.expanded

      Behavior on opacity {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutCubic
        }
      }

      Behavior on scale {
        NumberAnimation {
          duration: 190
          easing.type: Easing.OutCubic
        }
      }
    }

    Loader {
      id: expandedLoader

      anchors.fill: parent
      sourceComponent: expandedContent

      opacity: musicWidget.expanded ? 1 : 0
      scale: musicWidget.expanded ? 1 : 0.965
      enabled: musicWidget.expanded

      transform: Translate {
        y: musicWidget.expanded ? 0 : 7

        Behavior on y {
          NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
          }
        }
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 190
          easing.type: Easing.OutCubic
        }
      }

      Behavior on scale {
        NumberAnimation {
          duration: 220
          easing.type: Easing.OutCubic
        }
      }
    }

    Component {
      id: collapsedContent

      RowLayout {
        anchors.fill: parent

        anchors.leftMargin: 16
        anchors.rightMargin: 16

        spacing: 10

        Text {
          id: playerLabel

          Layout.alignment: Qt.AlignVCenter
          Layout.maximumWidth: 90

          text: musicWidget.player
          ? musicWidget.player.identity
          + (musicWidget.pinned ? " 📌" : "")
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

        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter

          text: {
            const p = musicWidget.player;

            if (!p || p.trackTitle === "")
            return "Nothing playing";

            return p.trackArtist !== ""
            ? p.trackTitle + "  -  " + p.trackArtist
            : p.trackTitle;
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
              if (mouse.button === Qt.LeftButton)
              musicWidget.expanded = true;
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

            color: btnArea.containsMouse
            ? RootDir.Theme.accentHover
            : RootDir.Theme.fg

            scale: btnArea.containsMouse ? 1.15 : 1

            Behavior on scale {
              NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
              }
            }

            MouseArea {
              id: btnArea

              anchors.fill: parent
              anchors.margins: -4

              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: {
                const p = musicWidget.player;

                if (!p)
                return;

                if (modelData.action === "toggle")
                p.togglePlaying();
                else if (modelData.action === "next")
                p.next();
                else if (p.position > 3)
                p.position = 0;
                else
                p.previous();
              }
            }
          }
        }
      }
    }

    Component {
      id: expandedContent

      Item {
        anchors.fill: parent

        readonly property real margin: 16

        RowLayout {
          anchors {
            fill: parent
            margins: 16
          }
          spacing: 14

          Rectangle {
            Layout.preferredWidth: 128
            Layout.preferredHeight: 128

            radius: 14
            color: "transparent"
            clip: true

            Image {
              id: cover

              anchors.fill: parent
              source: musicWidget.player
              ? musicWidget.player.trackArtUrl : ""
              fillMode: Image.PreserveAspectCrop
              visible: false
              asynchronous: true
              cache: true
            }

            OpacityMask {
              anchors.fill: parent
              source: cover

              maskSource: Rectangle {
                width: 128
                height: 128
                radius: 14
                color: "white"
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: musicWidget.player
                ? musicWidget.player.trackTitle : "Nothing playing"

                color: RootDir.Theme.fg
                font.family: RootDir.Fonts.text
                font.pixelSize: 17
                font.weight: Font.DemiBold

                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              Text {
                text: musicWidget.player
                ? musicWidget.player.trackArtist : ""

                color: RootDir.Theme.fgMuted
                font.family: RootDir.Fonts.text
                font.pixelSize: 13

                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              Text {
                text: musicWidget.player
                ? musicWidget.player.identity : ""

                color: RootDir.Theme.fgMuted
                font.family: RootDir.Fonts.text
                font.pixelSize: 10
                opacity: 0.7
              }
            }

            Item {
              Layout.fillHeight: true
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 7

              Item {
                id: spectrum

                Layout.fillWidth: true
                Layout.preferredHeight: 12
                clip: true
                transform: Translate { y: 20 }

                Rectangle {
                  anchors.left: parent.left
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: 2
                  radius: 1
                  color: RootDir.Theme.fgMuted
                  opacity: 0.25

                  Rectangle {
                    width: parent.width * musicWidget.progress
                    height: parent.height
                    radius: parent.radius
                    color: RootDir.Theme.accentHover
                  }
                }

                Repeater {
                  model: musicWidget.cavaLevels.length

                  delegate: Item {
                    required property int index

                    width: spectrum.width / musicWidget.cavaLevels.length
                    height: spectrum.height
                    x: index * width

                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.bottom: parent.bottom
                      width: parent.width * 0.62
                      height: Math.max(
                        2,
                        musicWidget.cavaLevels[index] * (parent.height - 2)
                      )
                      radius: 1
                      color: index / musicWidget.cavaLevels.length < musicWidget.progress
                      ? RootDir.Theme.accentHover
                      : Qt.darker(RootDir.Theme.accentHover, 2.3)
                    }
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                transform: Translate { y: 20 }

                Text {
                  text: musicWidget.player
                  ? Qt.formatTime(
                    new Date(musicWidget.player.position * 1000),
                    "m:ss"
                  ) : "0:00"

                  color: RootDir.Theme.fgMuted
                  font.family: RootDir.Fonts.text
                  font.pixelSize: 10
                }

                Item {
                  Layout.fillWidth: true
                }

                Text {
                  text: musicWidget.player
                  ? Qt.formatTime(
                    new Date(musicWidget.player.length * 1000),
                    "m:ss"
                  ) : "0:00"

                  color: RootDir.Theme.fgMuted
                  font.family: RootDir.Fonts.text
                  font.pixelSize: 10
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Item {
                  Layout.fillWidth: true
                }

                Repeater {
                  model: [
                  { glyph: "⏮", action: "prev" },
                  { glyph: "", action: "toggle" },
                  { glyph: "⏭", action: "next" }
                  ]

                  delegate: Item {
                    Layout.preferredWidth: modelData.action === "toggle"
                    ? 42 : 34
                    Layout.preferredHeight: 38

                    Text {
                      anchors.centerIn: parent

                      text: modelData.action === "toggle"
                      ? (musicWidget.isPlaying ? "⏸" : "▶")
                      : modelData.glyph

                      color: RootDir.Theme.fg
                      font.family: RootDir.Fonts.icon
                      font.pixelSize: modelData.action === "toggle"
                      ? 22 : 18

                      scale: mouseArea.containsMouse ? 1.12 : 1.0

                      Behavior on scale {
                        NumberAnimation {
                          duration: 120
                        }
                      }
                    }

                    MouseArea {
                      id: mouseArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor

                      onClicked: {
                        if (!musicWidget.player)
                        return

                        if (modelData.action === "prev")
                        musicWidget.player.previous()
                        else if (modelData.action === "next")
                        musicWidget.player.next()
                        else
                        musicWidget.player.togglePlaying()
                      }
                    }
                  }
                }

                Item {
                  Layout.fillWidth: true
                }
              }
            }
          }
        }
      }
    }
    // Progress bar
    Rectangle {
      visible: !musicWidget.expanded

      x: musicWidget.cornerRadius
      y: bg.height - height - 2

      height: 2
      radius: 1

      width: Math.round(
        (bg.width - musicWidget.cornerRadius * 2)
        * musicWidget.progress
      )

      color: RootDir.Theme.fg
      opacity: 0.6
    }
  }

  RootDir.ConcaveCorner {
    radius: musicWidget.cornerRadius
    color: bg.color
    mirror.x: true

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
