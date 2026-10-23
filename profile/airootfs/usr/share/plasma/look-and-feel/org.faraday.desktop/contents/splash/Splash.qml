import QtQuick
Rectangle {
    id: root; color: "#111111"; property int stage
    Image { id: logo; source: "images/logo.png"; anchors.centerIn: parent; anchors.verticalCenterOffset: -30
            width: Math.min(parent.width * 0.6, sourceSize.width); fillMode: Image.PreserveAspectFit; smooth: true }
    Rectangle { anchors.top: logo.bottom; anchors.topMargin: 30; anchors.horizontalCenter: parent.horizontalCenter
        width: root.width * 0.25; height: 4; radius: 2; color: "#33ffffff"
        Rectangle { height: parent.height; radius: 2; width: parent.width * root.stage / 6
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#e8611a" } GradientStop { position: 0.7; color: "#ffd21f" } GradientStop { position: 1; color: "#ffffff" } }
            Behavior on width { NumberAnimation { duration: 300 } } } }
}
