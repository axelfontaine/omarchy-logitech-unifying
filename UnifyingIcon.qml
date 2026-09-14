import QtQuick
import QtQuick.Shapes

// Logitech's Unifying icon mark (the flower/rounded-square glyph, icon
// portion only — no wordmark), extracted and recolored from the
// public-domain SVG on Wikimedia Commons: this logo "consists only of
// simple geometric shapes ... and is therefore in the public domain"
// (File:Logitech_Unifying_logo_orange.svg, commons.wikimedia.org).
Item {
  id: root

  property real iconSize: 16
  property color color: "white"

  implicitWidth: iconSize
  implicitHeight: iconSize

  // Centered first via anchors, then scaled around its own (already
  // centered) origin — more robust than scaling around a corner, which
  // only stays centered if the surrounding sizes line up exactly right.
  Item {
    id: shapeHolder
    width: 100
    height: 100
    anchors.centerIn: parent
    scale: root.iconSize / 100

    Shape {
      anchors.fill: parent
      antialiasing: true
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: root.color
        fillRule: ShapePath.OddEvenFill
        strokeWidth: 0
        PathSvg {
          path: "M 84.541 44.545 C 66.754 44.545 65.843 42.956 64.926 41.384 C 64.010 39.796 63.099 38.218 71.992 22.820 C 73.503 20.203 72.603 16.865 69.998 15.365 C 67.387 13.854 64.054 14.748 62.543 17.359 C 53.655 32.763 51.822 32.763 50.000 32.763 C 48.167 32.763 46.345 32.763 37.451 17.359 C 35.946 14.748 32.607 13.854 29.997 15.365 C 27.386 16.865 26.492 20.203 28.002 22.820 C 36.890 38.218 35.974 39.796 35.068 41.384 C 34.146 42.956 33.235 44.545 15.448 44.545 C 12.438 44.545 9.999 46.984 9.999 50.000 C 9.999 53.016 12.438 55.455 15.448 55.455 C 33.235 55.455 34.146 57.044 35.068 58.616 C 35.974 60.204 36.890 61.788 28.002 77.197 C 26.492 79.797 27.386 83.141 29.997 84.635 C 32.607 86.152 35.946 85.246 37.451 82.641 C 46.345 67.243 48.167 67.243 50.000 67.243 C 51.822 67.243 53.655 67.243 62.543 82.641 C 64.054 85.246 67.387 86.152 69.998 84.635 C 72.603 83.141 73.503 79.797 71.992 77.197 C 63.099 61.788 64.010 60.204 64.926 58.616 C 65.843 57.044 66.754 55.455 84.541 55.455 C 87.546 55.455 89.996 53.016 89.996 50.000 C 89.996 46.984 87.546 44.545 84.541 44.545 M 43.745 56.249 C 41.823 54.327 41.823 45.673 43.745 43.751 C 45.667 41.829 54.322 41.829 56.244 43.751 C 58.166 45.673 58.166 54.327 56.244 56.249 C 54.322 58.177 45.667 58.177 43.745 56.249 M 50.000 99.994 C 33.330 99.994 16.665 99.994 8.332 91.668 C -0.000 83.335 -0.000 66.670 -0.000 50.000 C -0.000 33.335 -0.000 16.670 8.332 8.332 C 16.665 0.006 33.330 0.006 50.000 0.006 C 66.665 0.006 83.324 0.006 91.662 8.332 C 100.000 16.670 100.000 33.335 100.000 50.000 C 100.000 66.670 100.000 83.335 91.662 91.668 C 83.324 99.994 66.665 99.994 50.000 99.994"
        }
      }
    }
  }
}
