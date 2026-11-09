import Foundation

/// A budget month. The budget is kept per calendar month.
public struct Month: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "month out of range: \(month)")
        self.year = year
        self.month = month
    }

    /// The month a calendar day falls into (Gregorian, given time zone).
    public init(containing date: Date, calendar: Calendar = .budget) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year!, month: parts.month!)
    }

    public var next: Month {
        month == 12 ? Month(year: year + 1, month: 1) : Month(year: year, month: month + 1)
    }

    public var previous: Month {
        month == 1 ? Month(year: year - 1, month: 12) : Month(year: year, month: month - 1)
    }

    /// Every month from `self` through `last`, inclusive. Empty if `last` is earlier.
    public func through(_ last: Month) -> [Month] {
        var result: [Month] = []
        var current = self
        while current <= last {
            result.append(current)
            current = current.next
        }
        return result
    }

    public static func < (lhs: Month, rhs: Month) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    public var description: String { String(format: "%04d-%02d", year, month) }
}

extension Calendar {
    /// Bookings are calendar days in Germany; this keeps month boundaries stable
    /// no matter which time zone the Mac is set to.
    public static let budget: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()
}
