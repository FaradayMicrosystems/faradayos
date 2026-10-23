import QtQuick

Rectangle {
    id: root
    color: "#0B0B0B"
    property int stage

    onStageChanged: {
        if (stage == 2) intro.running = true
        bar.width = Math.min(stage, 6) / 6 * track.width
    }

    Image {
        id: logo
        source: "images/logo.png"
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.4, sourceSize.width)
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0
        OpacityAnimator { id: intro; target: logo; from: 0; to: 1; duration: 600; easing.type: Easing.InOutQuad }
    }

    Rectangle {
        id: track
        anchors { top: logo.bottom; topMargin: 40; horizontalCenter: parent.horizontalCenter }
        width: logo.width * 0.6; height: 4; radius: 2; color: "#242424"
        Rectangle {
            id: bar
            height: parent.height; radius: 2; width: 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#FF7A1A" }
                GradientStop { position: 1.0; color: "#FFC53D" }
            }
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
        }
    }
}
