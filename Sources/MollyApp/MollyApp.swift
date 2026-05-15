import AppKit
import SwiftUI

/// Ensures the host window can shrink/grow without an implicit max size cap from AppKit defaults.
private struct WindowResizeConfigurator: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {

        let view = NSView()

        view.isHidden = true

        Self.configureWindow(for: view)

        return view

    }

    func updateNSView(_ nsView: NSView, context: Context) {

        Self.configureWindow(for: nsView)

    }

    private static func configureWindow(for view: NSView) {

        DispatchQueue.main.async {

            guard let window = view.window else { return }

            window.minSize = NSSize(width: 520, height: 360)

            window.maxSize = NSSize(width: 10000, height: 10000)

            window.styleMask.insert(.resizable)

        }

    }

}

@main
struct MollyBootstrap: App {

    @NSApplicationDelegateAdaptor(MollyAppDelegate.self) private var conductor

    var body: some Scene {

        WindowGroup {

            MainDashboard(surface: conductor.hub)

                .background(Color(nsColor: .windowBackgroundColor))

                .background(WindowResizeConfigurator())

                .onReceive(NotificationCenter.default.publisher(for: .mollyRevealDashboard)) { _ in

                    NSApplication.shared.activate(ignoringOtherApps: true)

                }

        }

        .defaultSize(width: 860, height: 520)

        Settings { EmptyView() }

    }

}
