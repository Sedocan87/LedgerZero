import WidgetKit
import SwiftUI

struct CategorySummary: Codable, Identifiable {
    let id: String
    let name: String
    let available: Double
    let percentFunded: Double
}

struct TransactionSummary: Codable, Identifiable {
    let id: String
    let payeeName: String
    let amount: Double
    let date: String
    let categoryName: String?
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tbbAmount: Double
    let categories: [CategorySummary]
    let recentTransactions: [TransactionSummary]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        // Return realistic dummy data for the skeleton view (redacted state)
        SimpleEntry(date: Date(), tbbAmount: 1234.56, categories: [
            CategorySummary(id: "1", name: "Category 1", available: 100.00, percentFunded: 0.5),
            CategorySummary(id: "2", name: "Category 2", available: 200.00, percentFunded: 0.8),
            CategorySummary(id: "3", name: "Category 3", available: 50.00, percentFunded: 0.2),
            CategorySummary(id: "4", name: "Category 4", available: 75.00, percentFunded: 0.4)
        ], recentTransactions: [
            TransactionSummary(id: "t1", payeeName: "Payee Name", amount: -50.00, date: "Today", categoryName: "Category"),
            TransactionSummary(id: "t2", payeeName: "Payee Name", amount: -20.00, date: "Yesterday", categoryName: "Category"),
            TransactionSummary(id: "t3", payeeName: "Payee Name", amount: 1000.00, date: "Fri", categoryName: "Income")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), tbbAmount: 1250.50, categories: [
            CategorySummary(id: "1", name: "Groceries", available: 150.00, percentFunded: 0.75),
            CategorySummary(id: "2", name: "Rent", available: 0.00, percentFunded: 0.0),
            CategorySummary(id: "3", name: "Dining Out", available: 45.00, percentFunded: 0.45),
            CategorySummary(id: "4", name: "Transport", available: 20.00, percentFunded: 0.20)
        ], recentTransactions: [
            TransactionSummary(id: "t1", payeeName: "Supermarket", amount: -45.50, date: "Today", categoryName: "Groceries"),
            TransactionSummary(id: "t2", payeeName: "Gas Station", amount: -30.00, date: "Yesterday", categoryName: "Transport"),
            TransactionSummary(id: "t3", payeeName: "Salary", amount: 2500.00, date: "Friday", categoryName: "Inflow")
        ])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.ledgerzero.app")
        let tbb = userDefaults?.double(forKey: "tbb_amount") ?? 0.0

        var categories: [CategorySummary] = []
        if let jsonString = userDefaults?.string(forKey: "categories_json"),
           let jsonData = jsonString.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([CategorySummary].self, from: jsonData) {
                categories = decoded
            }
        }

        var transactions: [TransactionSummary] = []
        if let jsonString = userDefaults?.string(forKey: "transactions_json"),
           let jsonData = jsonString.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([TransactionSummary].self, from: jsonData) {
                transactions = decoded
            }
        }

        let entry = SimpleEntry(date: Date(), tbbAmount: tbb, categories: categories, recentTransactions: transactions)

        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text("To Be Budgeted")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatCurrency(entry.tbbAmount))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(entry.tbbAmount >= 0 ? Color.green : Color.red)
                .minimumScaleFactor(0.5)

            Spacer()

            Text(entry.date, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .widgetURL(URL(string: "ledgerzero://budget"))
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        HStack {
            // Left side: TBB
            VStack(alignment: .leading) {
                Text("To Be Budgeted")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatCurrency(entry.tbbAmount))
                    .font(.title2)
                    .bold()
                    .foregroundColor(entry.tbbAmount >= 0 ? Color.green : Color.red)
                    .minimumScaleFactor(0.8)

                Spacer()

                Text(entry.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 120, alignment: .leading)
            .padding(.trailing, 8)

            Divider()

            // Right side: Category list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.categories.prefix(4)) { category in
                    Link(destination: URL(string: "ledgerzero://budget?category=\(category.id)")!) {
                        HStack {
                            Circle()
                                .fill(category.available >= 0 ? Color.green : Color.red)
                                .frame(width: 8, height: 8)

                            Text(category.name)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text(formatCurrency(category.available))
                                .font(.caption)
                                .bold()
                                .foregroundColor(category.available >= 0 ? .primary : .red)
                        }
                    }
                }
                if entry.categories.isEmpty {
                    Text("No categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "ledgerzero://budget"))
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            // Header: TBB
            HStack {
                VStack(alignment: .leading) {
                    Text("To Be Budgeted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(entry.tbbAmount))
                        .font(.title3)
                        .bold()
                        .foregroundColor(entry.tbbAmount >= 0 ? Color.green : Color.red)
                }
                Spacer()
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Divider()

            Text("Recent Transactions")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach(entry.recentTransactions.prefix(5)) { tx in
                    Link(destination: URL(string: "ledgerzero://transaction?id=\(tx.id)")!) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tx.payeeName)
                                    .font(.subheadline)
                                    .bold()
                                    .lineLimit(1)
                                if let category = tx.categoryName {
                                    Text(category)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(formatCurrency(tx.amount))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(tx.amount > 0 ? .green : .primary)

                                Text(tx.date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if entry.recentTransactions.isEmpty {
                    Text("No recent transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
            }
            Spacer()
        }
        .padding()
        .widgetURL(URL(string: "ledgerzero://transactions"))
    }
}

func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
}

struct LedgerZeroWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct LedgerZeroWidget: Widget {
    let kind: String = "LedgerZeroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LedgerZeroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("Your budget at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LedgerZeroWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LedgerZeroWidgetEntryView(entry: SimpleEntry(date: Date(), tbbAmount: 1250.50, categories: [], recentTransactions: []))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            LedgerZeroWidgetEntryView(entry: SimpleEntry(date: Date(), tbbAmount: 2450.00, categories: [
                CategorySummary(id: "1", name: "Groceries", available: 150.00, percentFunded: 0.75),
                CategorySummary(id: "2", name: "Rent", available: 0.00, percentFunded: 0.0),
                CategorySummary(id: "3", name: "Dining Out", available: -45.00, percentFunded: 0.45),
                CategorySummary(id: "4", name: "Transport", available: 20.00, percentFunded: 0.20)
            ], recentTransactions: []))
            .previewContext(WidgetPreviewContext(family: .systemMedium))

            LedgerZeroWidgetEntryView(entry: SimpleEntry(date: Date(), tbbAmount: 1250.50, categories: [], recentTransactions: [
                TransactionSummary(id: "t1", payeeName: "Supermarket", amount: -45.50, date: "Today", categoryName: "Groceries"),
                TransactionSummary(id: "t2", payeeName: "Gas Station", amount: -30.00, date: "Yesterday", categoryName: "Transport"),
                TransactionSummary(id: "t3", payeeName: "Salary", amount: 2500.00, date: "Fri", categoryName: "Inflow")
            ]))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
