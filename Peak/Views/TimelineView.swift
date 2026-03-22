import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @State private var selectedDate = Date()
    @State private var activities: [ActivityEvent] = []
    @State private var appUsage: [(name: String, minutes: Int)] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Timeline")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Spacer()
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Button("Today") { selectedDate = Date() }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider().foregroundStyle(Color.creamDark)

            HSplitView {
                activityList
                    .frame(minWidth: 320)
                usageSummary
                    .frame(minWidth: 200, maxWidth: 260)
            }
        }
        .background(Color.cream)
        .onAppear { reload() }
        .onChange(of: selectedDate) { _ in reload() }
    }

    private var activityList: some View {
        Group {
            if activities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.inkLight.opacity(0.4))
                    Text("No Activity")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Text("Nothing recorded for \(selectedDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .background(Color.cream)
    }

    private var usageSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("App Usage")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)
                .padding(16)

            Divider().foregroundStyle(Color.creamDark)

            if appUsage.isEmpty {
                Spacer()
                Text("No data")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.inkLight)
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
        .background(Color.peachLight.opacity(0.5))
    }

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
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkLight)
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
            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.inkLight.opacity(0.6))
                .frame(width: 60, alignment: .trailing)
                .padding(.top, 2)

            VStack(spacing: 0) {
                Circle()
                    .fill(Color.peachAccent.opacity(0.7))
                    .frame(width: 7, height: 7)
                    .padding(.top, 3)
                Rectangle()
                    .fill(Color.creamDark)
                    .frame(width: 1)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.appName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ink)
                if !event.windowTitle.isEmpty {
                    Text(event.windowTitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .lineLimit(1)
                }
                if let url = event.url, let host = URL(string: url)?.host {
                    Text(host)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.peachAccent)
                }
            }
            .padding(.leading, 6)
            .padding(.bottom, 8)

            Spacer()
        }
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
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Spacer()
                Text(durationLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.inkLight)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.creamDark)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.peachAccent.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)
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
                .foregroundStyle(Color.inkLight.opacity(0.4))
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)
            Text(subtitle)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.inkLight)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
