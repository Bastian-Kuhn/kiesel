import Foundation
import Observation
import KieselCore

enum SidebarItem: Hashable {
    case budget
    case allAccounts
    case account(UUID)
}

enum BudgetFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case overspent = "Überzogen"
    case underfunded = "Unterdeckt"
    case available = "Geld verfügbar"
    var id: String { rawValue }
}

/// In-memory state of one household budget. Persistence (local store plus
/// iCloud sharing for the household) replaces the sample data in stage 2.
@Observable
@MainActor
final class BudgetStore {
    var householdName: String
    var accounts: [Account]
    var groups: [CategoryGroup]
    var categories: [BudgetCategory]
    var transactions: [Transaction]
    var entries: [BudgetEntry]
    var month: Month
    var selection: SidebarItem? = .budget
    var filter: BudgetFilter = .all
    var collapsedGroups: Set<UUID> = []

    init(householdName: String, accounts: [Account], groups: [CategoryGroup],
         categories: [BudgetCategory], transactions: [Transaction], entries: [BudgetEntry],
         month: Month) {
        self.householdName = householdName
        self.accounts = accounts
        self.groups = groups
        self.categories = categories
        self.transactions = transactions
        self.entries = entries
        self.month = month
    }

    var engine: BudgetEngine {
        BudgetEngine(accounts: accounts, transactions: transactions, entries: entries)
    }

    var summary: MonthSummary { engine.summary(for: month) }
    var previousSummary: MonthSummary { engine.summary(for: month.previous) }

    var sortedGroups: [CategoryGroup] { groups.sorted { $0.sortOrder < $1.sortOrder } }

    func categories(in group: CategoryGroup) -> [BudgetCategory] {
        categories.filter { $0.groupID == group.id && !$0.hidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func category(_ id: UUID) -> BudgetCategory? { categories.first { $0.id == id } }
    func account(_ id: UUID) -> Account? { accounts.first { $0.id == id } }

    func balance(_ account: Account) -> Money { transactions.balance(of: account.id) }

    func accounts(of kind: AccountKind) -> [Account] { accounts.filter { $0.kind == kind } }

    func total(of kind: AccountKind) -> Money { accounts(of: kind).sum { balance($0) } }

    func colorIndex(of account: Account) -> Int { accounts.firstIndex(of: account) ?? 0 }
    func colorIndex(of group: CategoryGroup) -> Int { sortedGroups.firstIndex(of: group) ?? 0 }

    func colorIndex(ofCategory id: UUID) -> Int {
        guard let category = category(id), let group = groups.first(where: { $0.id == category.groupID })
        else { return 0 }
        return colorIndex(of: group)
    }

    func matches(_ row: CategoryMonth, _ category: BudgetCategory, _ filter: BudgetFilter) -> Bool {
        let status = row.status(target: category.monthlyTarget)
        switch filter {
        case .all: return true
        case .overspent: return status == .overspent
        case .underfunded: if case .underfunded = status { return true } else { return false }
        case .available: return row.available.cents > 0
        }
    }

    func count(_ filter: BudgetFilter, in summary: MonthSummary) -> Int {
        categories.filter { !$0.hidden && matches(summary.category($0.id), $0, filter) }.count
    }

    /// Sets what is assigned to a category in the current month (not a delta).
    func setAssigned(_ amount: Money, for categoryID: UUID) {
        entries.removeAll { $0.categoryID == categoryID && $0.month == month }
        if amount != .zero {
            entries.append(BudgetEntry(categoryID: categoryID, month: month, assigned: amount))
        }
    }

    /// Transactions for the list view, newest first.
    func transactions(for item: SidebarItem?) -> [Transaction] {
        let list: [Transaction]
        switch item {
        case .account(let id): list = transactions.filter { $0.accountID == id }
        default: list = transactions
        }
        return list.sorted { $0.date > $1.date }
    }

    func categoryLabel(_ transaction: Transaction) -> (String, Int?)? {
        guard transaction.splits.count == 1, let split = transaction.splits.first else {
            return ("Aufgeteilt", nil)
        }
        switch split.assignment {
        case .readyToAssign: return ("Zu verteilen", nil)
        case .category(let id): return (category(id)?.name ?? "?", colorIndex(ofCategory: id))
        case .transfer(let id): return ("Umbuchung \(account(id)?.name ?? "")", nil)
        case .uncategorized: return nil
        }
    }
}

// MARK: - Sample data (generic, no real accounts)

extension BudgetStore {
    static func sample(today: Date = .now) -> BudgetStore {
        let giro = Account(name: "Girokonto", kind: .budget)
        let gemeinsam = Account(name: "Gemeinschaftskonto", kind: .budget)
        let bar = Account(name: "Bargeld", kind: .budget)
        let tagesgeld = Account(name: "Tagesgeld", kind: .budget)
        let karte = Account(name: "Kreditkarte", kind: .creditCard)
        let depot = Account(name: "Depot", kind: .tracking)

        var groups: [CategoryGroup] = []
        var categories: [BudgetCategory] = []
        func group(_ name: String, _ items: [(String, Int?)]) -> [UUID] {
            let g = CategoryGroup(name: name, sortOrder: groups.count)
            groups.append(g)
            return items.enumerated().map { index, item in
                let c = BudgetCategory(groupID: g.id, name: item.0, sortOrder: index,
                                       monthlyTarget: item.1.map { Money(euros: $0) })
                categories.append(c)
                return c.id
            }
        }
        let fix = group("Fixkosten", [("Miete", 1100), ("Strom & Gas", 140), ("Internet & Handy", 65),
                                      ("Versicherungen", 90)])
        let abos = group("Abos", [("Streaming", 18), ("Cloud-Speicher", 10), ("Zeitung", 15)])
        let alltag = group("Alltag", [("Lebensmittel", 600), ("Drogerie", 60), ("Mobilität", 120),
                                      ("Restaurant & Café", nil)])
        let freizeit = group("Freizeit", [("Sport", 45), ("Ausflüge", nil), ("Bücher", nil),
                                          ("Geschenke", nil)])
        let ruecklagen = group("Rücklagen", [("Urlaub", 250), ("Auto", 100), ("Notgroschen", nil)])

        let month = Month(containing: today)
        let previous = month.previous
        let cal = Calendar.budget
        func day(_ m: Month, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: m.year, month: m.month, day: d, hour: 12))!
        }

        var tx: [Transaction] = []
        func book(_ account: Account, _ m: Month, _ d: Int, _ cents: Int, _ payee: String,
                  _ memo: String = "", _ assignment: Assignment) {
            tx.append(Transaction(accountID: account.id, date: day(m, d), amount: Money(cents: cents),
                                  payee: payee, memo: memo, assignment: assignment))
        }

        for m in [previous, month] {
            book(giro, m, 1, 320_000, "Arbeitgeber GmbH", "Gehalt", .readyToAssign)
            book(gemeinsam, m, 1, 110_000, "Dauerauftrag", "Anteil Miete", .readyToAssign)
            book(gemeinsam, m, 2, -110_000, "Hausverwaltung", "Miete", .category(fix[0]))
            book(giro, m, 3, -13_600, "Stadtwerke", "Abschlag", .category(fix[1]))
            book(giro, m, 4, -6_499, "Telekommunikation AG", "", .category(fix[2]))
            book(karte, m, 5, -1_799, "Streamingdienst", "", .category(abos[0]))
            book(karte, m, 5, -999, "Cloud-Anbieter", "", .category(abos[1]))
        }
        book(giro, previous, 8, -9_000, "Versicherung AG", "Haftpflicht + Hausrat", .category(fix[3]))
        book(giro, previous, 6, -14_211, "Supermarkt", "Wocheneinkauf", .category(alltag[0]))
        book(giro, previous, 13, -12_870, "Supermarkt", "Wocheneinkauf", .category(alltag[0]))
        book(giro, previous, 20, -15_640, "Biomarkt", "", .category(alltag[0]))
        book(giro, previous, 27, -13_390, "Supermarkt", "", .category(alltag[0]))
        book(giro, previous, 11, -4_900, "Verkehrsverbund", "Monatsticket", .category(alltag[2]))
        book(bar, previous, 15, -6_450, "Pizzeria", "", .category(alltag[3]))
        book(giro, previous, 18, -3_499, "Buchhandlung", "", .category(freizeit[2]))
        book(giro, previous, 30, -25_000, "Umbuchung", "", .transfer(accountID: tagesgeld.id))
        book(tagesgeld, previous, 30, 25_000, "Umbuchung", "", .transfer(accountID: giro.id))

        book(giro, month, 3, -8_645, "Supermarkt", "Wocheneinkauf", .category(alltag[0]))
        book(bar, month, 4, -1_280, "Bäckerei", "", .category(alltag[0]))
        book(giro, month, 6, -11_920, "Biomarkt", "", .category(alltag[0]))
        book(giro, month, 5, -2_385, "Drogeriemarkt", "", .category(alltag[1]))
        book(giro, month, 7, -4_900, "Verkehrsverbund", "Monatsticket", .category(alltag[2]))
        book(karte, month, 7, -6_200, "Bahn", "Fahrkarte", .category(alltag[2]))
        book(karte, month, 8, -8_740, "Restaurant am Markt", "", .category(alltag[3]))
        book(giro, month, 8, -4_500, "Sportverein", "Beitrag", .category(freizeit[0]))
        book(karte, month, 9, -5_999, "Onlineshop", "", .uncategorized)
        book(giro, month, 9, -2_069, "Apotheke", "", .uncategorized)
        book(bar, month, 2, 20_000, "Geldautomat", "", .transfer(accountID: giro.id))
        book(giro, month, 2, -20_000, "Geldautomat", "", .transfer(accountID: bar.id))
        book(tagesgeld, previous, 1, 820_000, "Startsaldo", "", .readyToAssign)
        book(depot, previous, 1, 2_450_000, "Startsaldo", "", .readyToAssign)

        var entries: [BudgetEntry] = []
        func assign(_ m: Month, _ id: UUID, _ euros: Int) {
            entries.append(BudgetEntry(categoryID: id, month: m, assigned: Money(euros: euros)))
        }
        for m in [previous, month] {
            assign(m, fix[0], 1100); assign(m, fix[1], 140); assign(m, fix[2], 65)
            assign(m, abos[0], 18); assign(m, abos[1], 10)
            assign(m, alltag[0], 550); assign(m, alltag[1], 60); assign(m, alltag[2], 80)
            assign(m, freizeit[0], 45); assign(m, ruecklagen[0], 250)
        }
        assign(previous, fix[3], 90); assign(previous, alltag[3], 80); assign(previous, freizeit[2], 40)
        assign(previous, ruecklagen[1], 100); assign(previous, ruecklagen[2], 7_000)
        assign(month, fix[3], 45); assign(month, alltag[3], 50); assign(month, ruecklagen[1], 60)
        assign(month, freizeit[3], 40)

        return BudgetStore(householdName: "Unser Haushalt", accounts: [giro, gemeinsam, bar, tagesgeld, karte, depot],
                           groups: groups, categories: categories, transactions: tx, entries: entries,
                           month: month)
    }
}
