import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.Commons

// Persistent desktop clock with a battery read-out underneath. Sits on the
// layer just above the wallpaper: below normal windows, fully click-through.
//
// Both lines share the LCD treatment — a dim "ghost" renders the unlit
// segments behind the live digits. The clock follows the theme accent; the
// battery is coloured by charge: green 50–100, yellow 21–49, red ≤ 20.

Item {
  id: root

  // Injected by the shell host for panel-kind plugins.
  property var shell: null

  // Gap from the screen edge. Keeps the widget clear of the rounded corner
  // and, when the bar sits at the top, below it.
  readonly property int gap: Math.max(Style.gapsOut * 2, 16)
  readonly property int barClearance: (root.shell && root.shell.bar
    && root.shell.bar.position === "top") ? (root.shell.bar.barSize || 0) : 0

  // ---- Battery state -----------------------------------------------------
  // UPower reports percentage as a fraction (0.0–1.0).
  readonly property bool hasBattery: UPower.displayDevice !== null
    && UPower.displayDevice.isPresent === true
  readonly property int batteryPct: root.hasBattery
    ? Math.round(UPower.displayDevice.percentage * 100) : 0

  readonly property color batteryGreen: "#00ff66"
  readonly property color batteryYellow: "#ffd400"
  readonly property color batteryRed: "#ff3b30"
  readonly property color batteryColor: batteryPct >= 50
    ? batteryGreen
    : (batteryPct >= 21 ? batteryYellow : batteryRed)

  readonly property string batteryText: String(root.batteryPct)

  // ---- Clock state -------------------------------------------------------
  readonly property color lcdColor: Color.accent

  function pad(n) {
    var s = "0" + n
    return s.substring(s.length - 2)
  }

  readonly property string timeText: pad(clock.date.getHours()) + ":"
    + pad(clock.date.getMinutes())

  // ---- Temperature state -------------------------------------------------
  // e.g. "7°C" — DSEG7 supports digits and the degree sign.
  property string temperatureText: ""

  readonly property string temperatureDisplay: root.temperatureText

  function lcdGhost(text) {
    return String(text || "").replace(/[0-9]/g, "8")
  }

  readonly property string temperatureGhost: root.lcdGhost(root.temperatureDisplay)

  function updateTemperature(raw) {
    var value = String(raw || "").trim().replace(/^\+/, "")
    if (value !== "") temperatureText = value
  }

  // ---- Sizing ------------------------------------------------------------
  readonly property int clockFontSize: 54
  readonly property int batteryFontSize: 36
  readonly property int temperatureFontSize: 24
  readonly property int columnSpacing: Style.space(10)

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // Current temperature for the configured location (see
  // omarchy-weather-location). Refreshes every 15 minutes; a failed fetch
  // keeps the last known value so the line under the battery never goes empty.
  Process {
    id: tempProc
    running: true
    command: ["bash", "-c", "q=$(omarchy-weather-location | tr -d '\\n' | jq -sRr @uri); curl -fsS --max-time 5 \"https://wttr.in/${q}?format=%t\" | tr -d '\\n'"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateTemperature(text) }
  }

  Timer {
    id: tempTimer
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    onTriggered: if (!tempProc.running) tempProc.running = true
  }

  PanelWindow {
    id: panel
    screen: Quickshell.screens[0]
    visible: true
    anchors { top: true; left: true }
    margins {
      top: root.barClearance + root.gap
      left: root.gap
    }
    implicitWidth: Math.max(clockGhost.implicitWidth, batteryGhost.implicitWidth, tempGhost.implicitWidth)
    implicitHeight: clockGhost.implicitHeight
      + (root.hasBattery
        ? root.columnSpacing + batteryGhost.implicitHeight : 0)
      + (root.temperatureDisplay !== ""
        ? root.columnSpacing + tempGhost.implicitHeight : 0)
    color: "transparent"
    surfaceFormat.opaque: false

    WlrLayershell.namespace: "omarchy-desktop-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Column {
      spacing: root.columnSpacing

      // ---- Clock (HH:MM) ------------------------------------------------
      Item {
        width: clockGhost.implicitWidth
        height: clockGhost.implicitHeight

        Text {
          id: clockGhost
          anchors.fill: parent
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          text: "88:88"
          font.family: "DSEG7 Classic"
          font.pixelSize: root.clockFontSize
          color: Qt.rgba(root.lcdColor.r, root.lcdColor.g, root.lcdColor.b, 0.12)
        }

        Text {
          anchors.fill: parent
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          text: root.timeText
          font.family: "DSEG7 Classic"
          font.pixelSize: root.clockFontSize
          color: root.lcdColor
        }
      }

      // ---- Battery (NN) ---------------------------------------------------
      Item {
        visible: root.hasBattery
        width: batteryGhost.implicitWidth
        height: batteryGhost.implicitHeight

        Text {
          id: batteryGhost
          anchors.fill: parent
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          text: "888"
          font.family: "DSEG7 Classic"
          font.pixelSize: root.batteryFontSize
          color: Qt.rgba(root.batteryColor.r, root.batteryColor.g, root.batteryColor.b, 0.12)
        }

        Text {
          anchors.fill: parent
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          text: root.batteryText
          font.family: "DSEG7 Classic"
          font.pixelSize: root.batteryFontSize
          color: root.batteryColor
        }
      }

      // ---- Temperature (NN°C LOC) ----------------------------------------
      Item {
        visible: root.temperatureDisplay !== ""
        width: tempGhost.implicitWidth
        height: tempGhost.implicitHeight

        Text {
          id: tempGhost
          anchors.fill: parent
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          text: root.temperatureGhost
          font.family: "DSEG7 Classic"
          font.pixelSize: root.temperatureFontSize
          color: Qt.rgba(root.lcdColor.r, root.lcdColor.g, root.lcdColor.b, 0.12)
        }

        Text {
          anchors.fill: parent
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          text: root.temperatureDisplay
          font.family: "DSEG7 Classic"
          font.pixelSize: root.temperatureFontSize
          color: root.lcdColor
        }
      }
    }
  }
}
