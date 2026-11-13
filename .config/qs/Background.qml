import QtQuick
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    screen: modelData
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore
    property string targetWallpaper: Theme.wallpaper
    readonly property size wallpaperSourceSize: Qt.size(
        modelData.width * modelData.devicePixelRatio,
        modelData.height * modelData.devicePixelRatio
    )

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Image {
        id: currentWallpaper
        anchors.fill: parent
        source: Theme.wallpaper
        sourceSize: wallpaperSourceSize
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }

    Image {
        id: incomingWallpaper
        anchors.fill: parent
        opacity: 0
        sourceSize: wallpaperSourceSize
        asynchronous: true
        fillMode: Image.PreserveAspectCrop

        onStatusChanged: {
            if (status === Image.Ready)
                crossfade.start()
        }
    }

    NumberAnimation {
        id: crossfade
        target: incomingWallpaper
        property: "opacity"
        from: 0
        to: 1
        duration: 700
        onFinished: {
            currentWallpaper.source = incomingWallpaper.source
            incomingWallpaper.source = ""
            incomingWallpaper.opacity = 0
        }
    }

    onTargetWallpaperChanged: {
        if (targetWallpaper === currentWallpaper.source) {
            crossfade.stop()
            incomingWallpaper.opacity = 0
            incomingWallpaper.source = ""
            return
        }

        crossfade.stop()
        incomingWallpaper.opacity = 0
        incomingWallpaper.source = targetWallpaper
    }
}
