import AppKit

@MainActor
final class MollyAppDelegate: NSObject, NSApplicationDelegate {

    let hub = MollySessionController()

    private var menu: MenuCoordinator?

    private var workspaceSleepWakeObservers: [NSObjectProtocol] = []

    func applicationWillFinishLaunching(_ notification: Notification) {

        let coordinator = MenuCoordinator(sessionBrain: hub)

        menu = coordinator

        hub.menuBridge = coordinator

        coordinator.install()

        NSApp.setActivationPolicy(.regular)

    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        hub.beginStartupHousekeeping()

        Task { await NotificationThrottleCoordinator.shared.requestAuthorizationIfNeeded() }

        menu?.rebuild()

        installWorkspaceSleepWakeLogging()

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        false

    }

    func applicationWillTerminate(_ notification: Notification) {

        removeWorkspaceSleepWakeLogging()

        hub.shutdownBeforeTermination()

    }

    private func installWorkspaceSleepWakeLogging() {

        removeWorkspaceSleepWakeLogging()

        let center = NSWorkspace.shared.notificationCenter

        let willSleep = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hub.logSystemWillSleep()
            }
        }

        let didWake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hub.logSystemDidWake()
            }
        }

        workspaceSleepWakeObservers = [willSleep, didWake]

    }

    private func removeWorkspaceSleepWakeLogging() {

        let center = NSWorkspace.shared.notificationCenter

        for token in workspaceSleepWakeObservers {
            center.removeObserver(token)
        }

        workspaceSleepWakeObservers = []

    }

}
