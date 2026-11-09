import SwiftUI
import KieselCore

@main
struct KieselApp: App {
    @State private var store = BudgetStore.sample()

    init() {
        // `swift run` starts a bare binary without an app bundle; without this
        // it gets no Dock icon and no window. Inside Kiesel.app it is a no-op.
        NSApplication.shared.setActivationPolicy(.regular)
        if Bundle.main.bundleURL.pathExtension != "app",
           let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        if let path = Snapshot.requestedPath {
            Snapshot.render(to: path)
            exit(0)
        }
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("Kiesel") {
            ContentView()
                .environment(store)
                .frame(minWidth: 980, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 800)
    }
}

struct ContentView: View {
    @Environment(BudgetStore.self) private var store
    @State private var showInspector = true

    var body: some View {
        NavigationSplitView {
            Sidebar().navigationSplitViewColumnWidth(min: 230, ideal: 270)
        } detail: {
            switch store.selection {
            case .budget, nil:
                BudgetView()
                    .inspector(isPresented: $showInspector) {
                        MonthInspector().inspectorColumnWidth(min: 260, ideal: 300)
                    }
                    .toolbar {
                        Button { showInspector.toggle() } label: {
                            Label("Übersicht", systemImage: "sidebar.trailing")
                        }
                    }
            case .allAccounts, .account:
                TransactionsView(item: store.selection!)
            }
        }
        .navigationTitle("")
    }
}
