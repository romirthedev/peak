import Foundation
import AppKit

// MARK: - Date

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
    }

    var relativeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self)     { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return formatted(date: .abbreviated, time: .omitted)
    }

    var hourLabel: String {
        let h = Calendar.current.component(.hour, from: self)
        let suffix = h < 12 ? "AM" : "PM"
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display) \(suffix)"
    }
}

// MARK: - FileManager

extension FileManager {
    /// Recursively compute total size of a directory in bytes.
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

// MARK: - String

extension String {
    func truncated(to maxLength: Int, suffix: String = "…") -> String {
        count > maxLength ? String(prefix(maxLength)) + suffix : self
    }
}

// MARK: - NSWorkspace

extension NSWorkspace {
    var frontmostAppName: String {
        frontmostApplication?.localizedName ?? "Unknown"
    }
}
