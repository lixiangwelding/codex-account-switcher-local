import SwitcherCore
import AppKit
import SwiftUI

/// AppKit-backed status item host.
///
/// macOS 26 can move a SwiftUI `MenuBarExtra` into Control Center's blocked
/// list and then terminate the app when the item is removed.  Keeping the
/// status item in AppKit gives this app an explicit, stable lifetime and lets
/// the popover remain available even when the menu bar is being rearranged.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var model: AppModel!
    private var updater: AppUpdater!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu-bar-only app has no normal windows, so AppKit may otherwise
        // consider it eligible for automatic termination after launch.
        ProcessInfo.processInfo.disableAutomaticTermination(
            "Codex Account Switcher owns a persistent menu-bar status item"
        )
        ProcessInfo.processInfo.disableSuddenTermination()

        model = AppModel.live()
        updater = AppUpdater()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "CodexAccountSwitcherLocalStatusItem"
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.isHidden = false
            button.image = makeStatusItemImage()
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.toolTip = "Codex Account Switcher"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 326, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover(model: model, updater: updater)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func makeStatusItemImage() -> NSImage {
        if let image = NSImage(
            systemSymbolName: "person.crop.circle.fill",
            accessibilityDescription: "Codex Account Switcher"
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        ) {
            return image
        }

        let fallback = NSImage(size: NSSize(width: 18, height: 18))
        fallback.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 14, height: 14)).fill()
        fallback.unlockFocus()
        return fallback
    }
}

@main
struct SwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
