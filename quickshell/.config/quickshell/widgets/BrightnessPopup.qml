// BrightnessPopup.qml — screen brightness and warmth.
import QtQuick
import Quickshell
import qs

Popup {
  id: root

  cardWidth: 300
  align: "center"

  // The warmth slider runs neutral -> warm left to right, so dragging right
  // makes the screen warmer. That means inverting the Kelvin scale.
  readonly property real warmthFraction: (Backlight.neutralTemperature - Backlight.temperature) / (Backlight.neutralTemperature - Backlight.warmestTemperature)

  // ------------------------------------------------------------- brightness
  Item {
    width: parent.width
    height: 20

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "BRIGHTNESS"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Backlight.brightnessAvailable ? Math.round(Backlight.brightness * 100) + "%" : "unavailable"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Backlight.brightnessAvailable ? Theme.accent : Theme.fgDim
    }
  }

  Row {
    width: parent.width
    spacing: 10

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      horizontalAlignment: Text.AlignHCenter
      text: Backlight.brightness < 0.4 ? Icons.brightnessLow : Icons.brightness
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize + 2
      color: Theme.accent
    }

    Slider {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 30
      enabled: Backlight.brightnessAvailable
      value: Backlight.brightness
      onMoved: v => Backlight.setBrightness(v)
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: Theme.border
  }

  // ------------------------------------------------------------------ warmth
  Item {
    width: parent.width
    height: 20

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "WARMTH"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: !Backlight.temperatureAvailable ? "unavailable" : Backlight.temperature >= Backlight.neutralTemperature ? "off" : Backlight.temperature + "K"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: !Backlight.temperatureAvailable ? Theme.fgDim : Backlight.temperature >= Backlight.neutralTemperature ? Theme.fgDim : Backlight.kelvinToColor(Backlight.temperature)
    }
  }

  Row {
    width: parent.width
    spacing: 10

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      horizontalAlignment: Text.AlignHCenter
      text: Icons.warmth
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize + 2
      color: Backlight.temperatureAvailable ? Backlight.kelvinToColor(Backlight.temperature) : Theme.fgDim
    }

    Slider {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 30
      enabled: Backlight.temperatureAvailable
      value: root.warmthFraction
      // The fill is tinted with the actual blackbody colour of the selected
      // temperature, so the control shows you what it is about to do.
      fill: Backlight.kelvinToColor(Backlight.temperature)
      onMoved: v => Backlight.setTemperature(Backlight.neutralTemperature - v * (Backlight.neutralTemperature - Backlight.warmestTemperature))
    }
  }

  // hyprsunset is an optional package — say so plainly instead of shipping a
  // slider that moves but changes nothing.
  Row {
    width: parent.width
    spacing: 8
    visible: !Backlight.temperatureAvailable

    Text {
      anchors.top: parent.top
      text: Icons.alert
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: Theme.warn
    }

    Column {
      width: parent.width - 28
      spacing: 2

      Text {
        width: parent.width
        text: "Warmth needs hyprsunset."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fg
      }

      Text {
        width: parent.width
        text: "sudo pacman -S hyprsunset"
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }
    }
  }
}
