pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string provider: "codex"
    property string source: "cli"
    property bool ready: false
    property string errorMessage: ""
    property var payload: null

    readonly property bool loading: proc.running
    readonly property var usage: payload?.usage ?? null
    readonly property int primaryUsedPercent: usage?.primary?.usedPercent ?? -1
    readonly property int secondaryUsedPercent: usage?.secondary?.usedPercent ?? -1
    readonly property int primaryRemainingPercent: primaryUsedPercent >= 0 ? Math.max(0, 100 - Math.round(primaryUsedPercent)) : -1
    readonly property int secondaryRemainingPercent: secondaryUsedPercent >= 0 ? Math.max(0, 100 - Math.round(secondaryUsedPercent)) : -1
    readonly property real creditsRemaining: payload?.credits?.remaining ?? NaN
    readonly property string updatedAt: usage?.updatedAt ?? ""

    function reload(): void {
        if (!proc.running)
            proc.running = true;
    }

    function applyPayload(text: string): void {
        const trimmed = text.trim();
        ready = true;

        if (trimmed.length === 0) {
            payload = null;
            errorMessage = "No output from codexbar";
            return;
        }

        try {
            const parsed = JSON.parse(trimmed);
            const first = Array.isArray(parsed) ? parsed[0] : parsed;

            payload = first ?? null;
            errorMessage = first?.error?.message ?? "";
        } catch (error) {
            payload = null;
            errorMessage = "Failed to parse codexbar JSON";
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.reload()
    }

    Process {
        id: proc

        command: [
            "codexbar",
            "usage",
            "--provider",
            root.provider,
            "--source",
            root.source,
            "--format",
            "json",
            "--json-only"
        ]

        stdout: StdioCollector {
            onStreamFinished: root.applyPayload(text)
        }

        onExited: code => {
            if (code !== 0 && !root.errorMessage && !root.payload) {
                root.ready = true;
                root.errorMessage = `codexbar exited with code ${code}`;
            }
        }
    }
}
