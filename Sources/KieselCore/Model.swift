import Foundation

/// Plain value types for the budget. Persistence and iCloud sync map onto these;
/// the budget math in `BudgetEngine` only ever sees these types.

public enum AccountKind: String, Sendable, Codable, CaseIterable {
    /// Money that is budgeted: giro, cash, savings.
    case budget
    /// Credit card: budgeted, spending moves money into the card's payment category.
    case creditCard
    /// Only counted in net worth (depot, loan); never touches the budget.
    case tracking
}

public struct Account: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var kind: AccountKind

    public init(id: UUID = UUID(), name: String, kind: AccountKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public struct CategoryGroup: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int

    public init(id: UUID = UUID(), name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

public struct BudgetCategory: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var groupID: UUID
    public var name: String
    public var sortOrder: Int
    public var hidden: Bool
    /// What this category should get every month (first, simple kind of goal).
    public var monthlyTarget: Money?

    public init(id: UUID = UUID(), groupID: UUID, name: String, sortOrder: Int = 0,
                hidden: Bool = false, monthlyTarget: Money? = nil) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.sortOrder = sortOrder
        self.hidden = hidden
        self.monthlyTarget = monthlyTarget
    }
}

/// How a category stands in a month, for the status line and colours.
public enum CategoryStatus: Hashable, Sendable {
    /// Available is negative.
    case overspent
    /// Has a monthly target and this month's money does not reach it yet.
    case underfunded(missing: Money)
    /// Has a monthly target and reaches it.
    case funded
    /// Money came in and all of it was spent.
    case fullySpent
    /// Money available, no target.
    case available
    /// Nothing assigned, nothing spent.
    case empty
}

extension CategoryMonth {
    public func status(target: Money?) -> CategoryStatus {
        if available.isNegative { return .overspent }
        let funding = carriedOver + assigned
        if let target, target.cents > 0 {
            return funding < target ? .underfunded(missing: target - funding) : .funded
        }
        if funding.cents > 0 && available == .zero { return .fullySpent }
        if available.cents > 0 { return .available }
        return .empty
    }

    /// Share of the month's money already spent (0...1), for the progress bar.
    /// With a target and nothing spent yet, the share of the target funded.
    public func progress(target: Money?) -> Double {
        let funding = (carriedOver + assigned).cents
        let spent = -min(activity.cents, 0)
        if spent > 0 {
            return funding > 0 ? min(Double(spent) / Double(funding), 1) : 1
        }
        if let target, target.cents > 0 {
            return min(Double(funding) / Double(target.cents), 1)
        }
        return funding > 0 ? 0 : 0
    }
}

extension Sequence where Element == Transaction {
    /// Balance of an account: sum of all its transactions.
    public func balance(of accountID: UUID) -> Money {
        filter { $0.accountID == accountID }.sum(\.amount)
    }
}

/// Where the money of a transaction (or one split of it) goes.
public enum Assignment: Hashable, Sendable, Codable {
    /// Income that lands in "Zu verteilen".
    case readyToAssign
    /// Spending or refund in a category.
    case category(UUID)
    /// Transfer to/from another account. No category; budget neutral between
    /// two budget accounts.
    case transfer(accountID: UUID)
    /// Not categorised yet (fresh from the bank). Counts against nothing until
    /// categorised, but is shown as a to-do.
    case uncategorized
}

public struct Split: Hashable, Sendable, Codable {
    public var amount: Money
    public var assignment: Assignment

    public init(amount: Money, assignment: Assignment) {
        self.amount = amount
        self.assignment = assignment
    }
}

public enum ClearingState: String, Sendable, Codable {
    case pending, cleared, reconciled
}

public struct Transaction: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var accountID: UUID
    public var date: Date
    /// Positive = money in, negative = money out.
    public var amount: Money
    public var payee: String
    public var memo: String
    /// One split for a plain transaction; several for a split booking.
    /// The split amounts must add up to `amount`.
    public var splits: [Split]
    public var state: ClearingState
    /// Stable id from the bank import, for de-duplication.
    public var importID: String?

    public init(
        id: UUID = UUID(), accountID: UUID, date: Date, amount: Money,
        payee: String = "", memo: String = "", assignment: Assignment,
        state: ClearingState = .cleared, importID: String? = nil
    ) {
        self.init(id: id, accountID: accountID, date: date, amount: amount, payee: payee,
                  memo: memo, splits: [Split(amount: amount, assignment: assignment)],
                  state: state, importID: importID)
    }

    public init(
        id: UUID = UUID(), accountID: UUID, date: Date, amount: Money,
        payee: String = "", memo: String = "", splits: [Split],
        state: ClearingState = .cleared, importID: String? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.date = date
        self.amount = amount
        self.payee = payee
        self.memo = memo
        self.splits = splits
        self.state = state
        self.importID = importID
    }

    /// The splits do not add up to the amount.
    public var isUnbalanced: Bool { splits.sum(\.amount) != amount }
}

/// Money given a job: `amount` assigned to `categoryID` in `month`.
/// Moving money between categories is two of these (minus here, plus there).
public struct BudgetEntry: Hashable, Sendable, Codable {
    public var categoryID: UUID
    public var month: Month
    public var assigned: Money

    public init(categoryID: UUID, month: Month, assigned: Money) {
        self.categoryID = categoryID
        self.month = month
        self.assigned = assigned
    }
}
