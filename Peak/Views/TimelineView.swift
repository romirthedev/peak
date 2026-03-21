import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @State private var selectedDate = Date()
    @State private var activities: [ActivityEvent] = []
    @State private var appUsage: [(name: String, minutes: Int)] = []

    var body: some View {
        HSplitView {
            // Left panel: activity log
            activityList
                .frame(minWidth: 320)

            // Right panel: app usage summary
            usageSummary
                .frame(minWidth: 220, maxWidth: 280)
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            ToolbarItem(placement: .automatic) {
                Button("Today") { selectedDate = Date() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .onAppear { reload() }
        .onChange(of: selectedDate) { _ in reload() }
    }

    // MARK: - Subviews

    private var activityList: some View {
        Group {
            if activities.isEmpty {
                ContentPlaceholder(
                    icon: "clock",
                    title: "No Activity",
                    subtitle: "Nothing was recorded for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedByHour, id: \.hour) { group in
                            HourSection(hour: group.hour, events: group.events)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var usageSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("App usage")
                .font(.headline)
                .padding()

            Divider()

            if appUsage.isEmpty {
                Spacer()
                Text("No data")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        let total = appUsage.map(\.minutes).reduce(0, +)
                        ForEach(appUsage.prefix(15), id: \.name) { item in
                            AppUsageRow(name: item.name, minutes: item.minutes, total: total)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Data

    private var groupedByHour: [(hour: Int, events: [ActivityEvent])] {
        var dict: [Int: [ActivityEvent]] = [:]
        for event in activities {
            let h = Calendar.current.component(.hour, from: event.timestamp)
            dict[h, default: []].append(event)
        }
        return dict.sorted { $0.key < $1.key }.map { (hour: $0.key, events: $0.value) }
    }

    private func reload() {
        activities = orchestrator.activities(for: selectedDate)
        computeAppUsage()
    }

    private func computeAppUsage() {
        var usage: [String: TimeInterval] = [:]
        for event in activities {
            usage[event.appName, default: 0] += event.duration
        }
        appUsage = usage
            .map { (name: $0.key, minutes: max(1, Int($0.value / 60))) }
            .sorted { $0.minutes > $1.minutes }
    }
}

// MARK: - Subcomponents

private struct HourSection: View {
    let hour: Int
    let events: [ActivityEvent]

    private var hourLabel: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hourLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 6)
                .padding(.leading, 72)

            ForEach(events) { event in
                ActivityEventRow(event: event)
            }
        }
    }
}

private struct ActivityEventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time stamp
            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .trailing)
                .padding(.top, 2)

            // Dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(appColor(event.bundleIdentifier))
                    .frame(width: 7, height: 7)
                    .padding(.top, 3)
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1)
            }
            .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.appName)
                    .font(.callout.weight(.medium))
                if !event.windowTitle.isEmpty {
                    Text(event.windowTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let url = event.url, let host = URL(string: url)?.host {
                    Text(host)
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .padding(.leading, 6)
            .padding(.bottom, 8)

            Spacer()
        }
    }

    private func appColor(_ bundleId: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .yellow]
        let idx = abs(bundleId.hashValue) % colors.count
        return colors[idx]
    }
}

private struct AppUsageRow: View {
    let name: String
    let minutes: Int
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(minutes) / Double(total) : 0
    }

    private var durationLabel: String {
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                Text(durationLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 5)
        }
    }
}

private struct ContentPlaceholder: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
