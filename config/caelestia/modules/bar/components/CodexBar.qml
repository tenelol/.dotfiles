import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    readonly property bool hasPrimary: CodexBarService.primaryRemainingPercent >= 0
    readonly property bool hasSecondary: CodexBarService.secondaryRemainingPercent >= 0
    readonly property bool hasError: CodexBarService.errorMessage.length > 0
    readonly property color accent: {
        if (hasError)
            return Colours.palette.m3error;
        if (!hasPrimary)
            return Colours.palette.m3outline;
        if (CodexBarService.primaryRemainingPercent < 20)
            return Colours.palette.m3error;
        if (CodexBarService.primaryRemainingPercent < 40)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3secondary;
    }

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: content.implicitHeight + Appearance.padding.normal * 2
    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full
    clip: true

    StateLayer {
        anchors.fill: parent
        radius: root.radius

        function onClicked(): void {
            CodexBarService.reload();
        }
    }

    Column {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.spacing.small / 2

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            animate: !root.hasError && CodexBarService.loading
            text: root.hasError ? "error_outline" : CodexBarService.loading && !CodexBarService.ready ? "sync" : "terminal"
            color: root.accent
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: StyledText.AlignHCenter
            text: root.hasError ? "ERR" : root.hasPrimary ? `S${CodexBarService.primaryRemainingPercent}` : "--"
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.smaller
            color: root.accent
        }

        StyledText {
            visible: !root.hasError && root.hasSecondary
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: StyledText.AlignHCenter
            text: `W${CodexBarService.secondaryRemainingPercent}`
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
