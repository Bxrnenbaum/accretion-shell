pragma ComponentBehavior: Bound;

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "../" as RootDir

Item {
  id: dateWidget

  property real bodyWidth: expanded ? 360 : 140
  property bool expanded: false
  property bool panelActive: false
  property var selectedDate: new Date()
  property var displayedMonth: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
  property var calendarDays: []
  property var events: []
  readonly property string eventFile: Quickshell.shellDir + "/calendar-events.json"

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

  implicitHeight: expanded ? 390 : collapsedHeight
  implicitWidth: bodyWidth + cornerRadius * 2

  function dateKey(date) {
    return date.getFullYear() + "-"
      + String(date.getMonth() + 1).padStart(2, "0") + "-"
      + String(date.getDate()).padStart(2, "0");
  }

  function refreshCalendar() {
    const first = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1);
    const start = new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay());
    const today = dateKey(new Date());
    const selected = dateKey(selectedDate);
    const days = [];

    for (let index = 0; index < 42; index++) {
      const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index);
      const key = dateKey(date);
      days.push({
        date: date,
        day: date.getDate(),
        key: key,
        inMonth: date.getMonth() === displayedMonth.getMonth(),
        isToday: key === today,
        isSelected: key === selected,
        hasEvent: events.some(event => event.date === key)
      });
    }

    calendarDays = days;
  }

  function moveMonth(offset) {
    const targetMonth = new Date(selectedDate.getFullYear(), selectedDate.getMonth() + offset, 1);
    const lastDay = new Date(targetMonth.getFullYear(), targetMonth.getMonth() + 1, 0).getDate();
    selectedDate = new Date(targetMonth.getFullYear(), targetMonth.getMonth(), Math.min(selectedDate.getDate(), lastDay));
    displayedMonth = targetMonth;
  }

  function addEvent(title) {
    const trimmedTitle = title.trim();
    if (!trimmedTitle)
      return;

    events = events.concat([{ date: dateKey(selectedDate), title: trimmedTitle }]);
    saveEvents();
  }

  function removeEvent(index) {
    events = events.filter((event, eventIndex) => eventIndex !== index);
    saveEvents();
  }

  function saveEvents() {
    eventWriter.command = [
      "sh", "-c", "printf %s \"$1\" > \"$2\"", "sh",
      JSON.stringify(events), eventFile
    ];
    eventWriter.running = true;
  }

  onExpandedChanged: {
    if (expanded) {
      unloadTimer.stop();
      panelActive = true;
    } else {
      unloadTimer.restart();
    }
  }

  onSelectedDateChanged: refreshCalendar()
  onDisplayedMonthChanged: refreshCalendar()
  onEventsChanged: refreshCalendar()

  Component.onCompleted: {
    refreshCalendar();
    eventReader.running = true;
  }

  Timer {
    id: unloadTimer
    interval: 260
    onTriggered: dateWidget.panelActive = false
  }

  Process {
    id: eventReader
    command: [
      "sh", "-c",
      "cat \"$1\" 2>/dev/null || true",
      "sh", dateWidget.eventFile
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          let parsed = JSON.parse(text.trim());
          if (typeof parsed === "string")
            parsed = JSON.parse(parsed);
          if (Array.isArray(parsed)) {
            dateWidget.events = parsed.filter(event => event && typeof event.date === "string" && typeof event.title === "string");
            dateWidget.saveEvents();
          }
        } catch (error) {
          dateWidget.events = [];
        }
      }
    }
  }

  Process {
    id: eventWriter
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Rectangle {
    id: bg
    x: dateWidget.cornerRadius
    width: dateWidget.bodyWidth
    height: parent.height

    color: RootDir.Theme.bg

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: dateWidget.cornerRadius
    bottomRightRadius: dateWidget.cornerRadius

    Loader {
      anchors.fill: parent
      sourceComponent: collapsedContent
      opacity: dateWidget.expanded ? 0 : 1
      scale: dateWidget.expanded ? 0.985 : 1
      enabled: !dateWidget.expanded

      Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
      }

      Behavior on scale {
        NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
      }
    }

    Loader {
      anchors.fill: parent
      sourceComponent: expandedContent
      active: dateWidget.panelActive
      opacity: dateWidget.expanded ? 1 : 0
      scale: dateWidget.expanded ? 1 : 0.965
      visible: opacity > 0

      transform: Translate {
        y: dateWidget.expanded ? 0 : 7
        Behavior on y {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
      }

      Behavior on opacity {
        NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
      }

      Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }
    }

    Component {
      id: collapsedContent

      Item {
        Text {
          anchors.centerIn: parent
          font.family: RootDir.Fonts.text
          font.pixelSize: 15
          font.bold: true
          color: RootDir.Theme.fg
          text: Qt.formatDateTime(clock.date, "dd MMM HH:mm")
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: dateWidget.expanded = true
        }
      }
    }

    Component {
      id: expandedContent

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 5

        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 24

          Text {
            text: "‹"
            color: RootDir.Theme.fg
            font.pixelSize: 24
            font.family: RootDir.Fonts.text
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: dateWidget.moveMonth(-1)
            }
          }

          Text {
            Layout.fillWidth: true
            text: Qt.formatDate(dateWidget.displayedMonth, "MMMM yyyy")
            color: RootDir.Theme.fg
            font.family: RootDir.Fonts.text
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            text: "›"
            color: RootDir.Theme.fg
            font.pixelSize: 24
            font.family: RootDir.Fonts.text
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: dateWidget.moveMonth(1)
            }
          }
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 7
          rowSpacing: 1
          columnSpacing: 2

          Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            delegate: Text {
              required property string modelData
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: modelData
              color: RootDir.Theme.fgMuted
              font.family: RootDir.Fonts.text
              font.pixelSize: 10
            }
          }
        }

        GridLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          columns: 7
          rowSpacing: 2
          columnSpacing: 2

          Repeater {
            model: dateWidget.calendarDays
            delegate: Rectangle {
              id: dayCell
              required property var modelData
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: 20
              radius: 5
              color: modelData.isSelected ? RootDir.Theme.accent : "transparent"
              border.width: modelData.isToday && !modelData.isSelected ? 1 : 0
              border.color: RootDir.Theme.accentHover

              Text {
                anchors.centerIn: parent
                text: dayCell.modelData.day
                color: dayCell.modelData.isSelected ? RootDir.Theme.bg
                  : dayCell.modelData.inMonth ? RootDir.Theme.fg : RootDir.Theme.fgMuted
                opacity: dayCell.modelData.inMonth ? 1 : 0.45
                font.family: RootDir.Fonts.text
                font.pixelSize: 11
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: 3
                height: 3
                radius: 2
                color: dayCell.modelData.isSelected ? RootDir.Theme.bg : RootDir.Theme.accentHover
                visible: dayCell.modelData.hasEvent
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  dateWidget.selectedDate = dayCell.modelData.date;
                  if (dayCell.modelData.date.getMonth() !== dateWidget.displayedMonth.getMonth())
                    dateWidget.displayedMonth = new Date(
                      dayCell.modelData.date.getFullYear(),
                      dayCell.modelData.date.getMonth(),
                      1
                    );
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: Qt.formatDate(dateWidget.selectedDate, "dddd, d MMMM")
          color: RootDir.Theme.fg
          font.family: RootDir.Fonts.text
          font.pixelSize: 12
          font.bold: true
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          spacing: 8

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 5
            color: RootDir.Theme.bg

            TextInput {
              id: eventInput
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              verticalAlignment: TextInput.AlignVCenter
              color: RootDir.Theme.fg
              font.family: RootDir.Fonts.text
              font.pixelSize: 12
              clip: true
              onAccepted: {
                dateWidget.addEvent(text);
                text = "";
              }

              Text {
                visible: eventInput.text.length === 0
                text: "Add an event"
                color: RootDir.Theme.fgMuted
                font: eventInput.font
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Text {
            text: "+"
            color: RootDir.Theme.fg
            font.family: RootDir.Fonts.text
            font.pixelSize: 20
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                dateWidget.addEvent(eventInput.text);
                eventInput.text = "";
              }
            }
          }
        }

        ListView {
          Layout.fillWidth: true
          Layout.preferredHeight: 48
          clip: true
          spacing: 2
          model: dateWidget.events
            .map((event, index) => ({ event: event, index: index }))
            .filter(entry => entry.event.date === dateWidget.dateKey(dateWidget.selectedDate))

          delegate: RowLayout {
            id: eventRow
            required property var modelData
            width: ListView.view.width
            height: 20
            spacing: 6

            Rectangle {
              Layout.preferredWidth: 4
              Layout.preferredHeight: 4
              radius: 2
              color: RootDir.Theme.accentHover
            }

            Text {
              Layout.fillWidth: true
              text: eventRow.modelData.event.title
              color: RootDir.Theme.fgMuted
              font.family: RootDir.Fonts.text
              font.pixelSize: 11
              elide: Text.ElideRight
            }

            Text {
              text: "×"
              color: RootDir.Theme.fgMuted
              font.family: RootDir.Fonts.text
              font.pixelSize: 15
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: dateWidget.removeEvent(eventRow.modelData.index)
              }
            }
          }
        }
      }
    }

  }

  RootDir.ConcaveCorner {
    radius: dateWidget.cornerRadius
    color: bg.color
    mirror.x: true
    x: 0
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: dateWidget.cornerRadius
    color: bg.color
    x: dateWidget.width - dateWidget.cornerRadius
    y: 0
  }

  Behavior on bodyWidth {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  Behavior on implicitHeight {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  HyprlandFocusGrab {
    windows: [dateWidget.QsWindow.window]
    active: dateWidget.expanded
    onCleared: dateWidget.expanded = false
  }
}