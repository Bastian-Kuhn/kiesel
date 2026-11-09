import AppKit
import SwiftUI

/// `KIESEL_SNAPSHOT=<dir> swift run Kiesel` renders the main screens to PNG
/// files and exits. Lets a session without screen access look at the UI.
@MainActor
enum Snapshot {
    static var requestedPath: String? { ProcessInfo.processInfo.environment["KIESEL_SNAPSHOT"] }

    static func render(to directory: String) {
        let appearance = ProcessInfo.processInfo.environment["KIESEL_APPEARANCE"] == "dark"
            ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        let shots: [(String, (BudgetStore) -> Void)] = [
            ("budget", { $0.selection = .budget }),
            ("konto", { store in store.selection = .account(store.accounts[0].id) }),
            ("alle", { $0.selection = .allAccounts }),
        ]
        for (name, setup) in shots {
            let store = BudgetStore.sample()
            setup(store)
            let view = ContentView().environment(store).frame(width: 1280, height: 800)
            let hosting = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.appearance = appearance
            window.contentView = hosting
            window.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            hosting.layoutSubtreeIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { continue }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            print("wrote \(url.path)")
        }
    }
}
