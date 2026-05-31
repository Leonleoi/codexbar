import AppKit
import SwiftUI

@MainActor
final class DesktopMenuWindowController: NSWindowController {
    init(rootView: DesktopMenuView) {
        let hostingController = NSHostingController(rootView: rootView)
        let window = Self.makeWindow(contentViewController: hostingController)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static func makeWindow(contentViewController: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "CodexBar"
        window.contentViewController = contentViewController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 600)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = .clear
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.center()
        return window
    }
}
