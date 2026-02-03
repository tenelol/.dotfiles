pragma ComponentBehavior: Bound

import qs.components.misc
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    property alias lock: lock

    WlSessionLock {
        id: lock

        signal unlock

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    CustomShortcut {
        name: "lock"
        description: "Lock the current session"
        onPressed: lock.locked = true
    }

    CustomShortcut {
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    // Auto-suspend some time after the session is manually locked.
    Timer {
        id: suspendTimer

        interval: (Config.lock.suspendTimeout ?? 0) * 1000
        repeat: false
        running: lock.locked && (Config.lock.suspendTimeout ?? 0) > 0

        onTriggered: {
            if (lock.locked)
                Quickshell.execDetached(["systemctl", "suspend-then-hibernate"]);
        }
    }

    Connections {
        target: lock

        function onLockedChanged(): void {
            if (lock.locked && (Config.lock.suspendTimeout ?? 0) > 0)
                suspendTimer.restart();
            else
                suspendTimer.stop();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            lock.locked = true;
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }
    }
}
