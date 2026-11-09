import SwiftUI
import KieselCore

/// Kiesel's own look: warm stone neutrals, a moss green for "money has a job",
/// clay red for overspent, amber for underfunded.
enum Theme {
    static let moss = Color(red: 0.27, green: 0.62, blue: 0.45)
    static let clay = Color(red: 0.86, green: 0.33, blue: 0.27)
    static let amber = Color(red: 0.93, green: 0.64, blue: 0.20)
    static let stone = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let slate = Color(red: 0.30, green: 0.45, blue: 0.68)

    /// Colours for accounts and category groups, picked by position.
    static let palette: [Color] = [
        moss, slate, Color(red: 0.62, green: 0.45, blue: 0.75), amber,
        Color(red: 0.35, green: 0.65, blue: 0.70), clay, stone,
    ]

    static func color(at index: Int) -> Color { palette[index % palette.count] }

    static func amountColor(_ money: Money) -> Color {
        money.isNegative ? clay : .primary
    }
}

extension Money {
    /// "1.234,56 €" with the minus sign as a real minus.
    var display: String {
        formatted().replacingOccurrences(of: "-", with: "−")
    }
}

/// The rounded "available" badge at the end of a budget row.
struct AmountPill: View {
    let amount: Money
    let status: CategoryStatus

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(amount.display)
        }
        .font(.callout.monospacedDigit().weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(foreground)
        .background(Capsule().fill(background))
    }

    /// A zero balance is never a success colour, whatever the target says.
    private var neutral: Bool {
        amount == .zero && status != .overspent
    }

    private var symbol: String? {
        if neutral { return nil }
        return switch status {
        case .overspent: "exclamationmark"
        case .funded: "checkmark"
        case .underfunded: "circle.lefthalf.filled"
        default: nil
        }
    }

    private var foreground: Color {
        if neutral { return .secondary }
        return switch status {
        case .overspent: .white
        case .underfunded: .black.opacity(0.75)
        case .funded, .available: .white
        case .fullySpent, .empty: .secondary
        }
    }

    private var background: Color {
        if neutral { return Color.secondary.opacity(0.15) }
        return switch status {
        case .overspent: Theme.clay
        case .underfunded: Theme.amber
        case .funded, .available: Theme.moss
        case .fullySpent, .empty: Color.secondary.opacity(0.15)
        }
    }
}

/// Thin bar under a category name: how much of the month's money is used.
struct FundingBar: View {
    let progress: Double
    let status: CategoryStatus

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(color).frame(width: max(geo.size.width * progress, progress > 0 ? 3 : 0))
            }
        }
        .frame(height: 4)
    }

    private var color: Color {
        switch status {
        case .overspent: Theme.clay
        case .underfunded: Theme.amber
        default: Theme.moss
        }
    }
}

/// Colour dot in front of an account or category group.
struct Swatch: View {
    let color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 3).fill(color.gradient).frame(width: 12, height: 12)
    }
}

extension Date {
    var germanDay: String {
        formatted(.dateTime.weekday(.wide).day().month(.twoDigits).year()
            .locale(Locale(identifier: "de_DE")))
    }
    var germanShort: String {
        formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()
            .locale(Locale(identifier: "de_DE")))
    }
}

extension Month {
    var germanTitle: String {
        let date = Calendar.budget.date(from: DateComponents(year: year, month: month))!
        return date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "de_DE")))
    }
}
