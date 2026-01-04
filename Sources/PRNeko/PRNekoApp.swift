import SwiftUI
import AppKit
import Combine

@main
struct PRNekoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel = AppViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupObservers()
        updateStatusIcon()

        // Hide dock icon (backup in case Info.plist isn't used)
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupObservers() {
        // Watch for queue changes to update icon
        viewModel.$pendingReviews
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        viewModel.$mergeReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        viewModel.$blocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(viewModel: viewModel)
        )
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        let count = viewModel.totalActionableItems

        // SF Symbol icon
        if let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pet") {
            image.isTemplate = true
            button.image = image
        }
        button.title = count > 0 ? " \(count)" : ""
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                updateStatusIcon()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
