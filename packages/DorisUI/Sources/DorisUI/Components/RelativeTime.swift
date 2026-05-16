import Foundation

/// Static "X 分钟前" / "X minutes ago" formatter — used in note list rows
/// and the inline editor. Unlike SwiftUI's `Text(date, style: .relative)`
/// which re-renders every second (the user complained about the seconds
/// tick "20s, 21s, 22s…" jitter), this returns a snapshot string that
/// only changes when the view body re-evaluates for an actual reason
/// (data change, theme switch, etc.).
///
/// Granularity tiers (matches what feels natural for a notes app — sub-
/// minute resolution is noise; we don't really care if it's 12s or 18s):
///
///   < 60s        →  "刚刚"  / "Just now"
///   < 60 min     →  "X 分钟前" / "X min ago"
///   < 24 h       →  "X 小时前" / "X h ago"
///   < 7 d        →  "X 天前"   / "X d ago"
///   else         →  "MM-dd"   /  "MMM d"  (absolute date)
@MainActor
public enum RelativeTime {
    public static func short(_ date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))

        if elapsed < 60 {
            return L("Just now", "刚刚")
        }
        if elapsed < 60 * 60 {
            let mins = Int(elapsed / 60)
            return L("\(mins) min ago", "\(mins) 分钟前")
        }
        if elapsed < 24 * 60 * 60 {
            let hrs = Int(elapsed / 3600)
            return L("\(hrs) h ago", "\(hrs) 小时前")
        }
        if elapsed < 7 * 24 * 60 * 60 {
            let days = Int(elapsed / 86400)
            return L("\(days) d ago", "\(days) 天前")
        }
        // Older than a week — use an absolute date so "12 d ago" /
        // "47 d ago" doesn't become a guessing game.
        let f = DateFormatter()
        f.dateFormat = LanguageSettings.shared.mode == .english
            ? "MMM d"
            : "MM-dd"
        return f.string(from: date)
    }
}
