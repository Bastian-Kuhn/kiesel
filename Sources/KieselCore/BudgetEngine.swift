import Foundation

/// One category in one month.
public struct CategoryMonth: Hashable, Sendable {
    /// Positive balance carried over from the previous month.
    public var carriedOver: Money
    /// Money given to this category this month.
    public var assigned: Money
    /// Sum of all bookings on this category this month (spending is negative).
    public var activity: Money
    /// carriedOver + assigned + activity. Negative means overspent.
    public var available: Money { carriedOver + assigned + activity }

    public static let empty = CategoryMonth(carriedOver: .zero, assigned: .zero, activity: .zero)
}

public struct MonthSummary: Sendable {
    public var month: Month
    /// "Zu verteilen": money that has no job yet. Goal is zero.
    public var readyToAssign: Money
    /// Income booked this month.
    public var income: Money
    /// Total assigned this month.
    public var assigned: Money
    /// Overspending of the previous month, taken from "Zu verteilen" this month.
    public var overspentLastMonth: Money
    /// Spending that still waits for a category (bank import), this month.
    public var uncategorized: Money
    public var categories: [UUID: CategoryMonth]

    public func category(_ id: UUID) -> CategoryMonth { categories[id] ?? .empty }
}

/// The YNAB budget rules, as pure functions over plain values.
///
/// - Income goes to "Zu verteilen" (`Assignment.readyToAssign`).
/// - Every euro gets a job: assigning moves money from "Zu verteilen" into a
///   category for a month, also into future months.
/// - A positive balance rolls into the next month.
/// - A negative balance (overspent cash) does not roll: the category starts the
///   next month at zero and the deficit is taken from "Zu verteilen" there.
/// - Tracking accounts never touch the budget. Transfers between budget
///   accounts are budget neutral. A transfer from a budget to a tracking
///   account is spending and must be booked with a category on the budget side.
///
/// Not yet modelled: credit card payment categories (credit card accounts are
/// treated like budget accounts for now), goals.
public struct BudgetEngine: Sendable {
    public var accounts: [Account]
    public var transactions: [Transaction]
    public var entries: [BudgetEntry]
    public var calendar: Calendar

    public init(accounts: [Account], transactions: [Transaction], entries: [BudgetEntry],
                calendar: Calendar = .budget) {
        self.accounts = accounts
        self.transactions = transactions
        self.entries = entries
        self.calendar = calendar
    }

    public func summary(for target: Month) -> MonthSummary {
        let budgetAccounts = Set(accounts.filter { $0.kind != .tracking }.map(\.id))

        // Bucket every split of a budget account by month once.
        var income: [Month: Money] = [:]
        var uncategorized: [Month: Money] = [:]
        var activity: [Month: [UUID: Money]] = [:]
        for transaction in transactions where budgetAccounts.contains(transaction.accountID) {
            let month = Month(containing: transaction.date, calendar: calendar)
            for split in transaction.splits {
                switch split.assignment {
                case .readyToAssign:
                    income[month, default: .zero] += split.amount
                case .category(let id):
                    activity[month, default: [:]][id, default: .zero] += split.amount
                case .uncategorized:
                    uncategorized[month, default: .zero] += split.amount
                case .transfer:
                    break
                }
            }
        }

        var assigned: [Month: [UUID: Money]] = [:]
        for entry in entries {
            assigned[entry.month, default: [:]][entry.categoryID, default: .zero] += entry.assigned
        }

        let allMonths = Set(income.keys).union(activity.keys).union(assigned.keys)
            .union(uncategorized.keys)
        let first = min(allMonths.min() ?? target, target)

        var balances: [UUID: Money] = [:]   // available at end of the previous month
        var incomeSoFar = Money.zero
        var assignedSoFar = Money.zero
        var overspentSoFar = Money.zero
        var overspentPrevious = Money.zero
        var result = MonthSummary(month: target, readyToAssign: .zero, income: .zero,
                                  assigned: .zero, overspentLastMonth: .zero,
                                  uncategorized: .zero, categories: [:])

        for month in first.through(target) {
            let monthAssigned = assigned[month] ?? [:]
            let monthActivity = activity[month] ?? [:]
            let ids = Set(balances.keys).union(monthAssigned.keys).union(monthActivity.keys)

            var categories: [UUID: CategoryMonth] = [:]
            var overspent = Money.zero
            for id in ids {
                let carried = max(balances[id] ?? .zero, .zero)
                let row = CategoryMonth(carriedOver: carried,
                                        assigned: monthAssigned[id] ?? .zero,
                                        activity: monthActivity[id] ?? .zero)
                categories[id] = row
                balances[id] = row.available
                if row.available.isNegative { overspent += -row.available }
            }

            incomeSoFar += income[month] ?? .zero
            assignedSoFar += monthAssigned.values.sum { $0 }
            overspentSoFar += overspentPrevious

            if month == target {
                let futureAssigned = assigned.filter { $0.key > target }
                    .values.flatMap(\.values).sum { $0 }
                result = MonthSummary(
                    month: month,
                    readyToAssign: incomeSoFar - assignedSoFar - overspentSoFar - futureAssigned,
                    income: income[month] ?? .zero,
                    assigned: monthAssigned.values.sum { $0 },
                    overspentLastMonth: overspentPrevious,
                    uncategorized: uncategorized[month] ?? .zero,
                    categories: categories)
            }
            overspentPrevious = overspent
        }
        return result
    }
}
