import Quickshell.Io

JsonObject {
    property bool recolourLogo: false
    property bool enableFprint: true
    property int maxFprintTries: 3
    // Seconds to wait after manual lock before suspending. 0 disables auto-suspend.
    property int suspendTimeout: 600
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property real heightMult: 0.7
        property real ratio: 16 / 9
        property int centerWidth: 600
    }
}
