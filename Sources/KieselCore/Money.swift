import Foundation

/// A sum of money in whole cents. Never a floating point number.
public struct Money: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public var cents: Int

    public init(cents: Int) { self.cents = cents }

    /// Convenience for literals in tests and sample data: `Money(euros: 12, cents: 50)`.
    public init(euros: Int, cents: Int = 0) {
        self.cents = euros * 100 + (euros < 0 ? -cents : cents)
    }

    public static let zero = Money(cents: 0)

    public static func + (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents + rhs.cents) }
    public static func - (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents - rhs.cents) }
    public static prefix func - (value: Money) -> Money { Money(cents: -value.cents) }
    public static func += (lhs: inout Money, rhs: Money) { lhs.cents += rhs.cents }
    public static func -= (lhs: inout Money, rhs: Money) { lhs.cents -= rhs.cents }
    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    public var isNegative: Bool { cents < 0 }

    /// German formatting, e.g. `1.234,56 €`.
    public func formatted(locale: Locale = Locale(identifier: "de_DE")) -> String {
        let decimal = Decimal(cents) / 100
        return decimal.formatted(.currency(code: "EUR").locale(locale))
    }

    public var description: String { formatted() }
}

extension Sequence {
    public func sum(_ value: (Element) -> Money) -> Money {
        reduce(.zero) { $0 + value($1) }
    }
}
