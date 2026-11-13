import "." as RootDir
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: launcher

    property bool isOpen: false
    property bool windowVisible: false
    property string mode: "apps"
    property string statusText: ""
    readonly property var matchingApplications: {
        const query = searchInput.text.trim().toLowerCase();
        const applications = DesktopEntries.applications.values;
        if (query.length === 0)
            return applications.slice(0, 8);

        return applications.filter((application) => {
            const keywords = (application.keywords || []).join(" ");
            const searchable = [application.name, application.genericName, application.comment, keywords].join(" ").toLowerCase();
            return searchable.includes(query);
        }).slice(0, 8);
    }

    function show(nextMode) {
        mode = nextMode;
        statusText = "";
        isOpen = true;
        windowVisible = true;
        closeTimer.stop();
        focusTimer.start();
    }

    function close() {
        if (!isOpen)
            return ;

        isOpen = false;
        closeTimer.restart();
    }

    function toggleMode(nextMode) {
        mode = nextMode;
        searchInput.text = "";
        statusText = "";
        searchInput.forceActiveFocus();
    }

    function launchSelectedApplication() {
        if (!appList.currentItem)
            return ;

        appList.currentItem.application.execute();
        close();
    }

    function runBashCommand() {
        const commandText = searchInput.text.trim();
        if (commandText.length === 0 || bashProcess.running)
            return ;

        statusText = "Running...";
        bashProcess.command = ["bash", "-lc", commandText];
        bashProcess.running = true;
    }

    IpcHandler {
        function showApplications() {
            launcher.show("apps");
        }

        function showCommands() {
            launcher.show("bash");
        }

        target: "appLauncher"
    }

    Timer {
        id: focusTimer

        interval: 0
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: closeTimer

        interval: 230
        onTriggered: launcher.windowVisible = false
    }

    Process {
        id: bashProcess

        command: ["bash", "-lc", ""]
        onExited: (exitCode, exitStatus) => {
            statusText = exitCode === 0 ? "Finished" : `Exited with status ${exitCode}`;
        }
    }

    PanelWindow {
        visible: launcher.windowVisible
        implicitWidth: screen.width
        implicitHeight: screen.height
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: launcher.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    onClicked: launcher.close()
                }

            }

            Rectangle {
                id: launcherPanel

                property real collapsedHeight: 32
                property real baseRadius: collapsedHeight / 2
                property real radiusExponent: 0.4
                property real cornerRadius: Math.min(height / 2, baseRadius * Math.pow(Math.max(height, collapsedHeight) / collapsedHeight, radiusExponent))

                width: Math.min(parent.width - 24, Math.min(1000, Math.max(640, parent.width * 0.6)))
                height: contents.implicitHeight + 36
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                color: "transparent"
                opacity: launcher.isOpen ? 1 : 0
                scale: launcher.isOpen ? 1 : 0.33

                Rectangle {
                    id: panelBackground

                    x: launcherPanel.cornerRadius
                    width: launcherPanel.width - launcherPanel.cornerRadius * 2
                    height: launcherPanel.height
                    color: RootDir.Theme.bg
                    topLeftRadius: launcherPanel.cornerRadius
                    topRightRadius: launcherPanel.cornerRadius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                }

                RootDir.ConcaveCorner {
                    radius: launcherPanel.cornerRadius
                    color: panelBackground.color
                    mirror.x: true
                    mirror.y: true
                    x: 0
                    y: launcherPanel.height - radius
                }

                RootDir.ConcaveCorner {
                    radius: launcherPanel.cornerRadius
                    color: panelBackground.color
                    mirror.x: false
                    mirror.y: true
                    x: launcherPanel.width - launcherPanel.cornerRadius
                    y: launcherPanel.height - radius
                }

                Column {
                    id: contents

                    x: -10
                    y: 36
                    width: parent.width + 20
                    spacing: 10

                    Rectangle {
                        width: Math.min(parent.width * 0.82, parent.width - launcherPanel.cornerRadius * 2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 46
                        radius: 12
                        color: RootDir.Theme.bgSecondary
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: RootDir.Theme.accent

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                width: 34
                                height: parent.height
                                text: launcher.mode === "apps" ? "app" : "$"
                                color: RootDir.Theme.accent
                                font.family: RootDir.Fonts.text
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Item {
                                width: parent.width - 34 - parent.spacing
                                height: parent.height

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: launcher.mode === "apps" ? "Search applications" : "Run a Bash command"
                                    color: RootDir.Theme.fgMuted
                                    font.family: RootDir.Fonts.text
                                    font.pixelSize: 13
                                    visible: searchInput.text.length === 0
                                }

                                TextInput {
                                    id: searchInput

                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: RootDir.Theme.fg
                                    selectionColor: RootDir.Theme.accent
                                    selectedTextColor: RootDir.Theme.bg
                                    font.family: RootDir.Fonts.text
                                    font.pixelSize: 13
                                    clip: true
                                    selectByMouse: true
                                    onTextChanged: appList.currentIndex = 0
                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            launcher.close();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Tab) {
                                            launcher.toggleMode(launcher.mode === "apps" ? "bash" : "apps");
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (launcher.mode === "apps")
                                                launcher.launchSelectedApplication();
                                            else
                                                launcher.runBashCommand();
                                            event.accepted = true;
                                        } else if (launcher.mode === "apps" && event.key === Qt.Key_Down) {
                                            appList.currentIndex = Math.min(appList.currentIndex + 1, appList.count - 1);
                                            event.accepted = true;
                                        } else if (launcher.mode === "apps" && event.key === Qt.Key_Up) {
                                            appList.currentIndex = Math.max(appList.currentIndex - 1, 0);
                                            event.accepted = true;
                                        }
                                    }
                                }

                            }

                        }

                    }

                    ListView {
                        id: appList

                        width: Math.min(parent.width * 0.82, parent.width - launcherPanel.cornerRadius * 2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 400
                        clip: true
                        spacing: 3
                        model: launcher.matchingApplications
                        currentIndex: count > 0 ? 0 : -1

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property var application: modelData
                            readonly property bool selected: ListView.isCurrentItem

                            width: ListView.view.width
                            height: 44
                            radius: 8
                            color: selected ? RootDir.Theme.fg : (index % 2 ? RootDir.Theme.bgSecondary : "transparent")

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                IconImage {
                                    width: 26
                                    height: 26
                                    source: Quickshell.iconPath(application.icon || "application-x-executable", true)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - 48
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: application.name
                                        color: selected ? RootDir.Theme.bg : RootDir.Theme.fg
                                        font.family: RootDir.Fonts.text
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: application.genericName || application.comment
                                        color: selected ? RootDir.Theme.bgSecondary : RootDir.Theme.fgMuted
                                        font.family: RootDir.Fonts.text
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: appList.currentIndex = index
                                onClicked: {
                                    application.execute();
                                    launcher.close();
                                }
                            }

                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
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

                transform: Translate {
                    y: launcher.isOpen ? 0 : launcherPanel.height + 20

                    Behavior on y {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

}
