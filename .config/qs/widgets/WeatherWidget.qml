import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../" as RootDir

Item {
  id: weatherWidget

  implicitHeight: 32
  implicitWidth: 340

  // Vienna by default
  property real latitude: 48.21
  property real longitude: 16.37
  property bool metric: true
  property int refreshMinutes: 15

  property bool loaded: false
  property bool failed: false
  property real temperature: 0
  property real feelsLike: 0
  property real windSpeed: 0
  property int humidity: 0
  property int weatherCode: 0
  property bool isDay: true
  property real tempMax: 0
  property real tempMin: 0
  property string updatedAt: ""

  property bool showRange: false

  readonly property string unitSymbol: metric ? "°C" : "°F"
  readonly property string windUnit: metric ? "km/h" : "mph"

  // WMO weather code -> Nerd Font Weather Icons glyph + description
  function describe(code, day) {
    switch (code) {
      case 0:  return { icon: day ? "\ue30d" : "\ue32b", text: "Clear" };          // day_sunny / night_clear
      case 1:  return { icon: day ? "\ue30c" : "\ue32b", text: "Mostly clear" };   // day_sunny_overcast / night_clear
      case 2:  return { icon: day ? "\ue302" : "\ue37e", text: "Partly cloudy" };  // day_cloudy / night_alt_cloudy
      case 3:  return { icon: "\ue312", text: "Overcast" };                         // cloudy
      case 45:
      case 48: return { icon: "\ue313", text: "Fog" };                              // fog
      case 51:
      case 53:
      case 55: return { icon: "\ue31b", text: "Drizzle" };                          // sprinkle
      case 56:
      case 57: return { icon: "\ue3ad", text: "Freezing drizzle" };                 // sleet
      case 61: return { icon: "\ue31b", text: "Light rain" };                       // sprinkle
      case 63: return { icon: "\ue318", text: "Rain" };                             // rain
      case 65: return { icon: "\ue318", text: "Heavy rain" };                       // rain
      case 66:
      case 67: return { icon: "\ue3ad", text: "Freezing rain" };                    // sleet
      case 71:
      case 73:
      case 75:
      case 77: return { icon: "\ue31a", text: "Snow" };                             // snow
      case 80:
      case 81:
      case 82: return { icon: "\ue319", text: "Showers" };                          // showers
      case 85:
      case 86: return { icon: "\ue31a", text: "Snow showers" };                     // snow
      case 95: return { icon: "\ue31d", text: "Thunderstorm" };                     // thunderstorm
      case 96:
      case 99: return { icon: "\ue314", text: "Thunderstorm, hail" };               // hail
      default: return { icon: "\ue374", text: "Unknown" };                          // na
    }
  }

  readonly property var condition: describe(weatherCode, isDay)

  function round1(v) { return Math.round(v); }

  readonly property string url:
  "https://api.open-meteo.com/v1/forecast"
  + "?latitude=" + latitude
  + "&longitude=" + longitude
  + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
  + "&daily=temperature_2m_max,temperature_2m_min"
  + "&forecast_days=1&timezone=auto"
  + (metric ? "" : "&temperature_unit=fahrenheit&wind_speed_unit=mph")

  function applyData(text) {
    try {
      const d = JSON.parse(text);
      const c = d.current;
      temperature = c.temperature_2m;
      feelsLike = c.apparent_temperature;
      humidity = c.relative_humidity_2m;
      weatherCode = c.weather_code;
      isDay = c.is_day === 1;
      windSpeed = c.wind_speed_10m;
      tempMax = d.daily.temperature_2m_max[0];
      tempMin = d.daily.temperature_2m_min[0];
      updatedAt = Qt.formatTime(new Date(), "hh:mm");
      loaded = true;
      failed = false;
    } catch (e) {
      failed = true;
    }
  }

  Process {
    id: fetcher
    command: ["curl", "-sf", "--max-time", "10", weatherWidget.url]
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) weatherWidget.applyData(text);
        else weatherWidget.failed = true;
      }
    }
    onExited: (code) => { if (code !== 0) weatherWidget.failed = true; }
  }

  function refresh() {
    if (!fetcher.running) fetcher.running = true;
  }

  Timer {
    interval: weatherWidget.refreshMinutes * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: weatherWidget.refresh()
  }

  Timer {
    interval: weatherWidget.refreshMinutes * 2000
    repeat: true
    running: weatherWidget.failed
    onTriggered: weatherWidget.refresh()
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    color: "#0b1b26"

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: height / 2
    bottomRightRadius: height / 2

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: bg.height / 2
      anchors.rightMargin: bg.height / 2
      spacing: 10

      // condition icon
      Text {
        Layout.alignment: Qt.AlignVCenter
        text: weatherWidget.loaded ? weatherWidget.condition.icon : "\ue374"
        font.family: RootDir.Fonts.icons
        font.pixelSize: 16
        color: "#F2E8D5"
      }

      // temperature
      Text {
        Layout.alignment: Qt.AlignVCenter
        text: weatherWidget.loaded
        ? weatherWidget.round1(weatherWidget.temperature) + weatherWidget.unitSymbol
        : "--"
        font.family: RootDir.Fonts.text
        font.pixelSize: 14
        font.bold: true
        color: "#F2E8D5"
      }

      // description
      Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: {
          if (weatherWidget.failed && !weatherWidget.loaded) return "Weather unavailable";
          if (!weatherWidget.loaded) return "Loading…";
          return weatherWidget.condition.text;
        }
        elide: Text.ElideRight
        font.family: RootDir.Fonts.text
        font.pixelSize: 12
        color: weatherWidget.failed ? "#C97B7B" : "#7F9AAE"

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) weatherWidget.refresh();
            else weatherWidget.showRange = !weatherWidget.showRange;
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        visible: weatherWidget.loaded
        text: weatherWidget.showRange
        ? "↑" + weatherWidget.round1(weatherWidget.tempMax) + "° ↓" + weatherWidget.round1(weatherWidget.tempMin) + "°"
        : "feels " + weatherWidget.round1(weatherWidget.feelsLike) + "°"
        font.family: RootDir.Fonts.text
        font.pixelSize: 12
        color: "#7F9AAE"
      }

      // humidity
      Row {
        Layout.alignment: Qt.AlignVCenter
        visible: weatherWidget.loaded
        spacing: 3

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf043" // droplet
          font.family: RootDir.Fonts.icons
          font.pixelSize: 12
          color: "#7F9AAE"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: weatherWidget.humidity + "%"
          font.family: RootDir.Fonts.text
          font.pixelSize: 12
          color: "#7F9AAE"
        }
      }
    }
  }

  RootDir.ConcaveCorner {
    radius: bg.height / 2
    color: bg.color
    mirrored: true
    x: -width
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: bg.height / 2
    color: bg.color
    x: weatherWidget.width
    y: 0
  }
}
