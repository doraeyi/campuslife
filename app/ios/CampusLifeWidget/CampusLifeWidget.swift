import WidgetKit
import SwiftUI

struct ShiftEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftEntry {
        ShiftEntry(date: Date(), text: "讀取中...")
    }

    func getSnapshot(in context: Context, completion: @escaping (ShiftEntry) -> Void) {
        completion(ShiftEntry(date: Date(), text: currentText()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftEntry>) -> Void) {
        let entry = ShiftEntry(date: Date(), text: currentText())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func currentText() -> String {
        let defaults = UserDefaults(suiteName: "group.com.campuslife.app")
        return defaults?.string(forKey: "next_shift_text") ?? "目前沒有班表"
    }
}

struct CampusLifeWidgetEntryView: View {
    var entry: ShiftEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("我的班表")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(entry.text)
                .font(.headline)
        }
        .padding()
    }
}

struct CampusLifeWidget: Widget {
    let kind: String = "CampusLifeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CampusLifeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("我的班表")
        .description("顯示下一個班次")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
