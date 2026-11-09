import SwiftUI
import KieselCore

struct BudgetView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        let summary = store.summary
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                BudgetHeader(summary: summary)
                Divider()
                ColumnHeader()
                Divider()
            }
            .background(Color(nsColor: .windowBackgroundColor))
            ScrollView {
                LazyVStack(spacing: 0) {
                    if summary.uncategorized != .zero && store.filter == .all {
                        UncategorizedRow(amount: summary.uncategorized)
                    }
                    ForEach(store.sortedGroups) { group in
                        GroupSection(group: group, summary: summary)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

// MARK: - Header

private struct BudgetHeader: View {
    @Environment(BudgetStore.self) private var store
    let summary: MonthSummary

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                HStack(spacing: 6) {
                    MonthButton(symbol: "chevron.left") { store.month = store.month.previous }
                    Text(store.month.germanTitle)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .frame(minWidth: 170)
                    MonthButton(symbol: "chevron.right") { store.month = store.month.next }
                }
                ReadyToAssignCard(amount: summary.readyToAssign)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(BudgetFilter.allCases) { filter in
                    FilterChip(title: filter.rawValue,
                               count: filter == .all ? nil : store.count(filter, in: summary),
                               warning: filter == .overspent,
                               selected: store.filter == filter) { store.filter = filter }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct MonthButton: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(Circle().strokeBorder(Color.secondary.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }
}

private struct ReadyToAssignCard: View {
    let amount: Money

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(amount.display)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                Text(subtitle).font(.caption.weight(.medium))
            }
            Image(systemName: symbol).font(.system(size: 22))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(background))
    }

    private var subtitle: String {
        amount.isNegative ? "Mehr verteilt als vorhanden"
            : amount == .zero ? "Jeder Euro hat eine Aufgabe" : "Zu verteilen"
    }
    private var symbol: String {
        amount.isNegative ? "exclamationmark.triangle.fill"
            : amount == .zero ? "checkmark.circle.fill" : "arrow.right.circle.fill"
    }
    private var foreground: Color { amount == .zero ? .primary : .white }
    private var background: Color {
        amount.isNegative ? Theme.clay : amount == .zero ? Color.secondary.opacity(0.12) : Theme.moss
    }
}

private struct FilterChip: View {
    let title: String
    let count: Int?
    let warning: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if warning, let count, count > 0 {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.clay)
                }
                Text(title)
                if let count, count > 0 {
                    Text("\(count)").foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07)))
            .overlay(Capsule().strokeBorder(selected ? Color.accentColor : .clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Table

private enum Columns {
    static let amount: CGFloat = 120
    static let available: CGFloat = 130
}

private struct ColumnHeader: View {
    var body: some View {
        HStack {
            Text("KATEGORIE")
            Spacer()
            Text("ZUGEWIESEN").frame(width: Columns.amount, alignment: .trailing)
            Text("AKTIVITÄT").frame(width: Columns.amount, alignment: .trailing)
            Text("VERFÜGBAR").frame(width: Columns.available, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

private struct UncategorizedRow: View {
    @Environment(BudgetStore.self) private var store
    let amount: Money
    var body: some View {
        Button { store.selection = .allAccounts } label: {
            HStack {
                Image(systemName: "tray.full.fill").foregroundStyle(Theme.amber)
                Text("Buchungen ohne Kategorie").fontWeight(.medium)
                Spacer()
                Text(amount.display).frame(width: Columns.amount, alignment: .trailing)
                AmountPill(amount: amount, status: .overspent)
                    .frame(width: Columns.available, alignment: .trailing)
            }
            .monospacedDigit()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.amber.opacity(0.10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider()
    }
}

private struct GroupSection: View {
    @Environment(BudgetStore.self) private var store
    let group: CategoryGroup
    let summary: MonthSummary

    var body: some View {
        let rows = store.categories(in: group).map { ($0, summary.category($0.id)) }
        let visible = rows.filter { store.matches($0.1, $0.0, store.filter) }
        if !visible.isEmpty {
            let collapsed = store.collapsedGroups.contains(group.id)
            GroupRow(group: group, collapsed: collapsed,
                     assigned: rows.sum { $0.1.assigned },
                     activity: rows.sum { $0.1.activity },
                     available: rows.sum { $0.1.available })
            if !collapsed {
                ForEach(visible, id: \.0.id) { category, row in
                    CategoryRow(category: category, row: row)
                    Divider().padding(.leading, 44)
                }
            }
        }
    }
}

private struct GroupRow: View {
    @Environment(BudgetStore.self) private var store
    let group: CategoryGroup
    let collapsed: Bool
    let assigned: Money
    let activity: Money
    let available: Money

    var body: some View {
        HStack {
            Button {
                if collapsed { store.collapsedGroups.remove(group.id) }
                else { store.collapsedGroups.insert(group.id) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
                    .frame(width: 14)
            }
            .buttonStyle(.plain)
            Swatch(color: Theme.color(at: store.colorIndex(of: group)))
            Text(group.name).font(.headline)
            Spacer()
            Text(assigned.display).frame(width: Columns.amount, alignment: .trailing)
            Text(activity.display).frame(width: Columns.amount, alignment: .trailing)
            Text(available.display).frame(width: Columns.available, alignment: .trailing)
                .padding(.trailing, 8)
                .foregroundStyle(Theme.amountColor(available))
        }
        .font(.callout.monospacedDigit().weight(.semibold))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.07))
    }
}

private struct CategoryRow: View {
    @Environment(BudgetStore.self) private var store
    let category: BudgetCategory
    let row: CategoryMonth
    @State private var draft = ""
    @FocusState private var editing: Bool
    @State private var hovering = false

    var body: some View {
        let status = row.status(target: category.monthlyTarget)
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 12) {
                    Text(category.name).lineLimit(1).layoutPriority(1)
                    Spacer(minLength: 0)
                    Text(statusText(status))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(statusColor(status))
                }
                FundingBar(progress: row.progress(target: category.monthlyTarget), status: status)
            }
            .padding(.leading, 24)
            .padding(.trailing, 16)

            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(editing ? Color.accentColor : (hovering ? Color.secondary.opacity(0.4) : .clear)))
                .frame(width: Columns.amount)
                .focused($editing)
                .onSubmit(commit)
                .onChange(of: editing) { _, now in if !now { commit() } }
            Text(row.activity.display)
                .frame(width: Columns.amount, alignment: .trailing)
                .foregroundStyle(.secondary)
            AmountPill(amount: row.available, status: status)
                .frame(width: Columns.available, alignment: .trailing)
        }
        .font(.body.monospacedDigit())
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(hovering ? Color.secondary.opacity(0.05) : .clear)
        .onHover { hovering = $0 }
        .onAppear { draft = Self.text(row.assigned) }
        .onChange(of: row.assigned) { _, value in if !editing { draft = Self.text(value) } }
    }

    private func statusText(_ status: CategoryStatus) -> String {
        switch status {
        case .overspent: "Überzogen"
        case .underfunded(let missing): "Noch \(missing.display)"
        case .funded: "Gedeckt"
        case .fullySpent: "Aufgebraucht"
        case .available, .empty: ""
        }
    }

    private func statusColor(_ status: CategoryStatus) -> Color {
        switch status {
        case .overspent: Theme.clay
        case .underfunded: Theme.amber
        default: .secondary
        }
    }

    private func commit() {
        guard let cents = Self.parseCents(draft) else {
            draft = Self.text(row.assigned)
            return
        }
        store.setAssigned(Money(cents: cents), for: category.id)
        draft = Self.text(Money(cents: cents))
    }

    static func text(_ money: Money) -> String { money.display }

    /// Accepts "12", "12,5", "1.234,56", "-3,05" and "12,00 €". Nil for anything else.
    static func parseCents(_ text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return 0 }
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

// MARK: - Inspector

struct MonthInspector: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        let summary = store.summary
        let rows = summary.categories.values
        let targets = store.categories.compactMap(\.monthlyTarget).sum { $0 }
        let underfunded = store.categories.compactMap { category -> Money? in
            if case .underfunded(let missing) = summary.category(category.id).status(target: category.monthlyTarget) {
                return missing
            }
            return nil
        }.sum { $0 }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card(title: "\(store.month.germanTitle)") {
                    Line("Übertrag aus Vormonat", rows.sum(\.carriedOver))
                    Line("Zugewiesen", summary.assigned)
                    Line("Aktivität", rows.sum(\.activity))
                    Divider()
                    Line("Verfügbar", rows.sum(\.available), bold: true)
                }
                Card(title: "Ziele") {
                    Line("Monatsziele gesamt", targets)
                    Line("Noch offen", underfunded,
                         color: underfunded.cents > 0 ? Theme.amber : nil)
                }
                if summary.overspentLastMonth.cents > 0 || summary.uncategorized != .zero {
                    Card(title: "Achtung") {
                        if summary.overspentLastMonth.cents > 0 {
                            Line("Überzogen im Vormonat", -summary.overspentLastMonth, color: Theme.clay)
                        }
                        if summary.uncategorized != .zero {
                            Line("Ohne Kategorie", summary.uncategorized, color: Theme.amber)
                        }
                    }
                }
                Card(title: "Vermögen") {
                    Line("Budgetkonten", store.total(of: .budget))
                    Line("Kreditkarten", store.total(of: .creditCard))
                    Line("Trackingkonten", store.total(of: .tracking))
                    Divider()
                    Line("Gesamt", store.accounts.sum { store.balance($0) }, bold: true)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15)))
    }
}

private struct Line: View {
    let label: String
    let amount: Money
    var bold = false
    var color: Color?

    init(_ label: String, _ amount: Money, bold: Bool = false, color: Color? = nil) {
        self.label = label
        self.amount = amount
        self.bold = bold
        self.color = color
    }

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(amount.display).foregroundStyle(color ?? Theme.amountColor(amount))
        }
        .font(.callout.monospacedDigit().weight(bold ? .semibold : .regular))
    }
}
