import Foundation
import Testing
@testable import KieselCore

private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.budget.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

private struct Fixture {
    let giro = Account(name: "Giro", kind: .budget)
    let bar = Account(name: "Bar", kind: .budget)
    let depot = Account(name: "Depot", kind: .tracking)
    let group = CategoryGroup(name: "Alltag")
    let food: BudgetCategory
    let rent: BudgetCategory

    init() {
        food = BudgetCategory(groupID: group.id, name: "Lebensmittel")
        rent = BudgetCategory(groupID: group.id, name: "Miete")
    }

    var accounts: [Account] { [giro, bar, depot] }

    func engine(_ transactions: [Transaction], _ entries: [BudgetEntry]) -> BudgetEngine {
        BudgetEngine(accounts: accounts, transactions: transactions, entries: entries)
    }
}

private let nov = Month(year: 2026, month: 11)
private let dec = Month(year: 2026, month: 12)

@Test func incomeLandsInReadyToAssign() {
    let f = Fixture()
    let s = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 3000),
                    assignment: .readyToAssign),
    ], []).summary(for: nov)
    #expect(s.readyToAssign == Money(euros: 3000))
    #expect(s.income == Money(euros: 3000))
}

@Test func assigningGivesEveryEuroAJob() {
    let f = Fixture()
    let s = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 3000),
                    assignment: .readyToAssign),
        Transaction(accountID: f.giro.id, date: day(2026, 11, 3), amount: Money(euros: -120, cents: 40),
                    assignment: .category(f.food.id)),
    ], [
        BudgetEntry(categoryID: f.food.id, month: nov, assigned: Money(euros: 500)),
        BudgetEntry(categoryID: f.rent.id, month: nov, assigned: Money(euros: 1200)),
    ]).summary(for: nov)
    #expect(s.readyToAssign == Money(euros: 1300))
    #expect(s.category(f.food.id).available == Money(euros: 379, cents: 60))
    #expect(s.category(f.rent.id).available == Money(euros: 1200))
}

@Test func positiveBalanceRollsOver() {
    let f = Fixture()
    let engine = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 1000),
                    assignment: .readyToAssign),
        Transaction(accountID: f.giro.id, date: day(2026, 11, 10), amount: Money(euros: -300),
                    assignment: .category(f.food.id)),
    ], [BudgetEntry(categoryID: f.food.id, month: nov, assigned: Money(euros: 500))])
    let s = engine.summary(for: dec)
    #expect(s.category(f.food.id).carriedOver == Money(euros: 200))
    #expect(s.category(f.food.id).available == Money(euros: 200))
    #expect(s.readyToAssign == Money(euros: 500))
}

@Test func overspendingIsTakenFromNextMonthsReadyToAssign() {
    let f = Fixture()
    let engine = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 1000),
                    assignment: .readyToAssign),
        Transaction(accountID: f.bar.id, date: day(2026, 11, 20), amount: Money(euros: -80),
                    assignment: .category(f.food.id)),
    ], [BudgetEntry(categoryID: f.food.id, month: nov, assigned: Money(euros: 50))])

    let november = engine.summary(for: nov)
    #expect(november.category(f.food.id).available == Money(euros: -30))
    #expect(november.readyToAssign == Money(euros: 950))

    let december = engine.summary(for: dec)
    #expect(december.category(f.food.id).carriedOver == .zero)
    #expect(december.category(f.food.id).available == .zero)
    #expect(december.overspentLastMonth == Money(euros: 30))
    #expect(december.readyToAssign == Money(euros: 920))
}

@Test func futureAssignmentsReduceReadyToAssignNow() {
    let f = Fixture()
    let s = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 2000),
                    assignment: .readyToAssign),
    ], [BudgetEntry(categoryID: f.rent.id, month: dec, assigned: Money(euros: 1200))]).summary(for: nov)
    #expect(s.readyToAssign == Money(euros: 800))
}

@Test func trackingAccountsAndTransfersStayOutOfTheBudget() {
    let f = Fixture()
    let s = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 1000),
                    assignment: .readyToAssign),
        Transaction(accountID: f.depot.id, date: day(2026, 11, 2), amount: Money(euros: 5000),
                    assignment: .readyToAssign),
        Transaction(accountID: f.giro.id, date: day(2026, 11, 3), amount: Money(euros: -100),
                    assignment: .transfer(accountID: f.bar.id)),
        Transaction(accountID: f.bar.id, date: day(2026, 11, 3), amount: Money(euros: 100),
                    assignment: .transfer(accountID: f.giro.id)),
    ], []).summary(for: nov)
    #expect(s.readyToAssign == Money(euros: 1000))
}

@Test func splitBookingHitsEveryCategory() {
    let f = Fixture()
    let t = Transaction(accountID: f.giro.id, date: day(2026, 11, 5), amount: Money(euros: -150),
                        splits: [Split(amount: Money(euros: -100), assignment: .category(f.food.id)),
                                 Split(amount: Money(euros: -50), assignment: .category(f.rent.id))])
    #expect(!t.isUnbalanced)
    let s = f.engine([t], []).summary(for: nov)
    #expect(s.category(f.food.id).activity == Money(euros: -100))
    #expect(s.category(f.rent.id).activity == Money(euros: -50))
}

@Test func uncategorizedIsShownNotBudgeted() {
    let f = Fixture()
    let s = f.engine([
        Transaction(accountID: f.giro.id, date: day(2026, 11, 7), amount: Money(euros: -42),
                    assignment: .uncategorized),
    ], []).summary(for: nov)
    #expect(s.uncategorized == Money(euros: -42))
    #expect(s.readyToAssign == .zero)
}

@Test func moneyFormatsGerman() {
    #expect(Money(euros: 1234, cents: 56).formatted() == "1.234,56\u{00A0}€")
    #expect(Money(euros: -3, cents: 5).cents == -305)
}

@Test func monthArithmetic() {
    #expect(Month(year: 2026, month: 12).next == Month(year: 2027, month: 1))
    #expect(Month(year: 2027, month: 1).previous == Month(year: 2026, month: 12))
    #expect(nov.through(dec) == [nov, dec])
}

@Test func categoryStatus() {
    let target = Money(euros: 100)
    #expect(CategoryMonth(carriedOver: .zero, assigned: Money(euros: 40), activity: .zero)
        .status(target: target) == .underfunded(missing: Money(euros: 60)))
    #expect(CategoryMonth(carriedOver: Money(euros: 60), assigned: Money(euros: 40), activity: .zero)
        .status(target: target) == .funded)
    #expect(CategoryMonth(carriedOver: .zero, assigned: Money(euros: 10), activity: Money(euros: -20))
        .status(target: nil) == .overspent)
    #expect(CategoryMonth(carriedOver: .zero, assigned: Money(euros: 10), activity: Money(euros: -10))
        .status(target: nil) == .fullySpent)
    #expect(CategoryMonth.empty.status(target: nil) == .empty)
    #expect(CategoryMonth(carriedOver: .zero, assigned: Money(euros: 200), activity: Money(euros: -50))
        .progress(target: nil) == 0.25)
}

@Test func accountBalance() {
    let f = Fixture()
    let list = [
        Transaction(accountID: f.giro.id, date: day(2026, 11, 1), amount: Money(euros: 100),
                    assignment: .readyToAssign),
        Transaction(accountID: f.giro.id, date: day(2026, 11, 2), amount: Money(euros: -30),
                    assignment: .uncategorized),
        Transaction(accountID: f.bar.id, date: day(2026, 11, 2), amount: Money(euros: -5),
                    assignment: .uncategorized),
    ]
    #expect(list.balance(of: f.giro.id) == Money(euros: 70))
}
