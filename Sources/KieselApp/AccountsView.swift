import SwiftUI
import KieselCore

struct Sidebar: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selection) {
            Section {
                Label("Budget", systemImage: "square.grid.3x3.square").tag(SidebarItem.budget)
                Label("Alle Buchungen", systemImage: "list.bullet.rectangle").tag(SidebarItem.allAccounts)
            } header: {
                HStack(spacing: 8) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 22, height: 22)
                    Text(store.householdName).font(.headline).foregroundStyle(.primary)
                }
                .padding(.bottom, 6)
            }
            accountSection("Budgetkonten", .budget)
            accountSection("Kreditkarten", .creditCard)
            accountSection("Tracking", .tracking)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func accountSection(_ title: String, _ kind: AccountKind) -> some View {
        let accounts = store.accounts(of: kind)
        if !accounts.isEmpty {
            Section {
                ForEach(accounts) { account in
                    HStack(spacing: 8) {
                        Swatch(color: Theme.color(at: store.colorIndex(of: account)))
                        Text(account.name).lineLimit(1)
                        Spacer()
                        Text(store.balance(account).display)
                            .monospacedDigit()
                            .foregroundStyle(store.balance(account).isNegative ? Theme.clay : .secondary)
                    }
                    .tag(SidebarItem.account(account.id))
                }
            } header: {
                HStack {
                    Text(title)
                    Spacer()
                    Text(store.total(of: kind).display).monospacedDigit()
                }
            }
        }
    }
}

struct TransactionsView: View {
    @Environment(BudgetStore.self) private var store
    let item: SidebarItem

    var body: some View {
        let list = store.transactions(for: item)
        let days = Dictionary(grouping: list) { Calendar.budget.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
        VStack(spacing: 0) {
            header.background(Color(nsColor: .windowBackgroundColor))
            Divider()
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(days, id: \.key) { day, transactions in
                        Section {
                            ForEach(transactions) { transaction in
                                TransactionRow(transaction: transaction, showAccount: account == nil)
                                Divider()
                            }
                        } header: {
                            HStack {
                                Text(day.germanDay)
                                Spacer()
                                Text(transactions.sum(\.amount).display).monospacedDigit()
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 5)
                            .background(.bar)
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var account: Account? {
        if case .account(let id) = item { return store.account(id) }
        return nil
    }

    private var header: some View {
        let open = store.transactions(for: item).filter {
            if case .uncategorized = $0.splits.first?.assignment { return true }
            return false
        }.count
        return HStack(alignment: .firstTextBaseline) {
            if let account {
                Swatch(color: Theme.color(at: store.colorIndex(of: account)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account?.name ?? "Alle Buchungen")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(open == 0 ? "Alles zugeordnet" : open == 1 ? "1 Buchung ohne Kategorie" : "\(open) Buchungen ohne Kategorie")
                    .font(.callout)
                    .foregroundStyle(open > 0 ? Theme.amber : .secondary)
            }
            Spacer()
            if let account {
                let balance = store.balance(account)
                Text(balance.display)
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.amountColor(balance))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct TransactionRow: View {
    @Environment(BudgetStore.self) private var store
    let transaction: KieselCore.Transaction
    let showAccount: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryTag(label: store.categoryLabel(transaction))
                .frame(width: 140, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.payee).fontWeight(.semibold).lineLimit(1)
                Text(subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(transaction.amount.display)
                .font(.system(size: 15, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(transaction.amount.isNegative ? Theme.clay : Theme.moss)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }

    private var subtitle: String {
        var parts: [String] = []
        if showAccount, let name = store.account(transaction.accountID)?.name { parts.append(name) }
        if !transaction.memo.isEmpty { parts.append(transaction.memo) }
        parts.append(transaction.date.germanShort)
        return parts.joined(separator: " · ")
    }
}

private struct CategoryTag: View {
    let label: (String, Int?)?

    var body: some View {
        if let label {
            Text(label.0.uppercased())
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(label.1 == nil ? Color.secondary : .white)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(label.1.map { Theme.color(at: $0) } ?? Color.secondary.opacity(0.15)))
        } else {
            Text("OHNE KATEGORIE")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(Theme.amber)
                .background(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.amber, style: StrokeStyle(lineWidth: 1, dash: [3])))
        }
    }
}
