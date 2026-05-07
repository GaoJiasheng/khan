import Foundation
import SwiftUI
import Combine

/// One-shot snapshot of "what's the weather where the user is right now."
public struct WeatherSnapshot: Equatable {
    var temperatureC: Double
    var weatherCode: Int            // raw WMO code; resolve to text at view-time
    var symbolName: String          // SF Symbol
    var isDay: Bool
    var windSpeedKmh: Double
    var windDirectionDeg: Double    // meteorological "from" direction (0=N)
    var uvIndex: Double
    var precipitationProbability: Double  // 0-100, current hour
    var locationName: String        // city, state — short form for the bubble
    var fetchedAt: Date
}

/// Pulls the user's location (IP-based, no permission prompt) and the current
/// weather for that location from Open-Meteo. Refreshes hourly while alive.
@MainActor
public final class WeatherViewModel: ObservableObject {
    @Published public private(set) var snapshot: WeatherSnapshot?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?

    private var refreshTask: Task<Void, Never>?

    public init() {}

    public func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                // Sleep 1 hour between refreshes.
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
            }
        }
    }

    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refresh() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let location = await fetchLocation()
            let weather = try await fetchWeather(at: location)
            snapshot = WeatherSnapshot(
                temperatureC: weather.temperatureC,
                weatherCode: weather.code,
                symbolName: WeatherCode.symbol(for: weather.code, isDay: weather.isDay),
                isDay: weather.isDay,
                windSpeedKmh: weather.windSpeedKmh,
                windDirectionDeg: weather.windDirectionDeg,
                uvIndex: weather.uvIndex,
                precipitationProbability: weather.precipitationProbability,
                locationName: location.shortName,
                fetchedAt: Date()
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Location

    private struct Location {
        var latitude: Double
        var longitude: Double
        var shortName: String
    }

    /// IP-based geolocation. On any failure (network, blocked, malformed
    /// response, missing fields) we fall back to Singapore so the bubble
    /// still has something to show.
    private static var singaporeFallback: Location {
        Location(latitude: 1.3521, longitude: 103.8198,
                 shortName: L("Singapore", "新加坡"))
    }

    private func fetchLocation() async -> Location {
        let url = URL(string: "https://ipapi.co/json/")!
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("khan/0.2", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(IPAPIResponse.self, from: data)
            guard let lat = decoded.latitude, let lon = decoded.longitude else {
                return Self.singaporeFallback
            }
            let parts = [decoded.city, decoded.region_code ?? decoded.country_code]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            let name = parts.isEmpty ? "—" : parts.joined(separator: ", ")
            return Location(latitude: lat, longitude: lon, shortName: name)
        } catch {
            return Self.singaporeFallback
        }
    }

    private struct IPAPIResponse: Decodable {
        let city: String?
        let region_code: String?
        let country_code: String?
        let latitude: Double?
        let longitude: Double?
    }

    // MARK: - Weather

    private struct OMResponse: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
            let wind_speed_10m: Double?
            let wind_direction_10m: Double?
            let uv_index: Double?
        }
        struct Hourly: Decodable {
            let time: [String]
            let precipitation_probability: [Double?]?
        }
        let current: Current
        let hourly: Hourly?
    }

    private struct WeatherFetch {
        var temperatureC: Double
        var code: Int
        var isDay: Bool
        var windSpeedKmh: Double
        var windDirectionDeg: Double
        var uvIndex: Double
        var precipitationProbability: Double
    }

    private func fetchWeather(at loc: Location) async throws -> WeatherFetch {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(loc.latitude)),
            .init(name: "longitude", value: String(loc.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,uv_index"),
            .init(name: "hourly", value: "precipitation_probability"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "temperature_unit", value: "celsius"),
            .init(name: "wind_speed_unit", value: "kmh"),
            .init(name: "timezone", value: "auto"),
        ]
        var req = URLRequest(url: c.url!, timeoutInterval: 8)
        req.setValue("khan/0.2", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        let r = try JSONDecoder().decode(OMResponse.self, from: data)

        // Match the current-hour timestamp against the hourly array to pull the
        // current hour's precipitation probability. Open-Meteo's `current.time`
        // and `hourly.time[i]` use the same local-time string format
        // ("YYYY-MM-DDTHH:MM") with timezone=auto, so a string compare is enough.
        var rainChance: Double = 0
        if let hourly = r.hourly,
           let probs = hourly.precipitation_probability,
           let idx = hourly.time.firstIndex(of: r.current.time),
           idx < probs.count,
           let p = probs[idx] {
            rainChance = p
        }

        return WeatherFetch(
            temperatureC: r.current.temperature_2m,
            code: r.current.weather_code,
            isDay: r.current.is_day == 1,
            windSpeedKmh: r.current.wind_speed_10m ?? 0,
            windDirectionDeg: r.current.wind_direction_10m ?? 0,
            uvIndex: r.current.uv_index ?? 0,
            precipitationProbability: rainChance
        )
    }
}

// MARK: - Wind / UV helpers

public enum WindScale {
    /// Beaufort label for a km/h wind speed.
    @MainActor public
    static func beaufort(_ kmh: Double) -> String {
        switch kmh {
        case ..<1:    return L("Calm",          "无风")
        case ..<6:    return L("Light air",     "软风")
        case ..<12:   return L("Light breeze",  "轻风")
        case ..<20:   return L("Gentle breeze", "微风")
        case ..<29:   return L("Moderate",      "和风")
        case ..<39:   return L("Fresh",         "清风")
        case ..<50:   return L("Strong",        "强风")
        case ..<62:   return L("Near gale",     "疾风")
        case ..<75:   return L("Gale",          "大风")
        case ..<89:   return L("Strong gale",   "烈风")
        case ..<103:  return L("Storm",         "狂风")
        default:      return L("Hurricane",     "飓风")
        }
    }

    /// Compass abbreviation for a meteorological "from" direction in degrees.
    @MainActor public
    static func compass(_ deg: Double) -> String {
        let d = ((deg.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let en = ["N","NE","E","SE","S","SW","W","NW"]
        let zh = ["北","东北","东","东南","南","西南","西","西北"]
        let idx = Int((d + 22.5) / 45) % 8
        return L(en[idx], zh[idx])
    }
}

public enum UVScale {
    @MainActor public
    static func label(_ uv: Double) -> String {
        switch uv {
        case ..<3:   return L("Low",       "低")
        case ..<6:   return L("Moderate",  "中等")
        case ..<8:   return L("High",      "高")
        case ..<11:  return L("Very High", "很高")
        default:     return L("Extreme",   "极高")
        }
    }

    public static func tint(_ uv: Double) -> Color {
        switch uv {
        case ..<3:   return Color(red: 0.30, green: 0.85, blue: 0.55)   // green
        case ..<6:   return Color(red: 1.00, green: 0.85, blue: 0.30)   // yellow
        case ..<8:   return Color(red: 1.00, green: 0.55, blue: 0.20)   // orange
        case ..<11:  return Color(red: 1.00, green: 0.30, blue: 0.30)   // red
        default:     return Color(red: 0.85, green: 0.30, blue: 0.85)   // violet
        }
    }
}

public enum RainScale {
    @MainActor public
    static func label(_ pct: Double) -> String {
        switch pct {
        case ..<20:  return L("Unlikely",    "几乎不会")
        case ..<50:  return L("Possible",    "可能")
        case ..<80:  return L("Likely",      "很有可能")
        default:     return L("Very likely", "非常可能")
        }
    }

    public static func tint(_ pct: Double) -> Color {
        let cyan = Color(red: 0.0, green: 0.85, blue: 1.0)
        switch pct {
        case ..<20:  return cyan.opacity(0.55)
        case ..<50:  return cyan.opacity(0.85)
        case ..<80:  return Color(red: 0.30, green: 0.65, blue: 1.0)
        default:     return Color(red: 0.55, green: 0.45, blue: 1.0)
        }
    }
}

/// Maps Open-Meteo's WMO weather codes to short labels + SF Symbols.
public enum WeatherCode {
    /// Localized condition text. Resolved at view-time so language toggling updates live.
    @MainActor public
    static func text(for code: Int) -> String {
        switch code {
        case 0:           return L("Clear",            "晴")
        case 1:           return L("Mostly Clear",     "晴间多云")
        case 2:           return L("Partly Cloudy",    "局部多云")
        case 3:           return L("Overcast",         "阴")
        case 45, 48:      return L("Fog",              "雾")
        case 51, 53, 55:  return L("Drizzle",          "毛毛雨")
        case 56, 57:      return L("Freezing Drizzle", "冻毛毛雨")
        case 61, 63, 65:  return L("Rain",             "雨")
        case 66, 67:      return L("Freezing Rain",    "冻雨")
        case 71, 73, 75:  return L("Snow",             "雪")
        case 77:          return L("Snow Grains",      "米雪")
        case 80, 81, 82:  return L("Rain Showers",     "阵雨")
        case 85, 86:      return L("Snow Showers",     "阵雪")
        case 95:          return L("Thunderstorm",     "雷暴")
        case 96, 99:      return L("Thunderstorm",     "雷暴")
        default:          return "—"
        }
    }

    public static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0:        return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1:        return isDay ? "sun.max.fill" : "moon.fill"
        case 2:        return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:        return "cloud.fill"
        case 45, 48:   return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57:   return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67:   return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77:       return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86:   return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default:       return "questionmark"
        }
    }
}

/// Compact cyber-styled weather pill. Pink-cyan gradient stroke, monospace temp,
/// SF-Symbol icon. On hover, expands a detail panel below showing wind + UV.
public struct WeatherBubble: View {
    @ObservedObject var vm: WeatherViewModel
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var isExpanded: Bool = false

    public init(vm: WeatherViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 6) {
            mainPill
            if isExpanded, let s = vm.snapshot {
                detailPanel(for: s)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -4)),
                        removal: .opacity.combined(with: .offset(y: -4))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
        .animation(.easeInOut(duration: 0.25), value: vm.snapshot)
        // macOS: hover to expand. iOS: tap to expand (no hover available).
        #if os(macOS)
        .onHover { isExpanded = $0 }
        #else
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
        #endif
    }

    @ViewBuilder
    private var mainPill: some View {
        if let s = vm.snapshot {
            content(for: s)
        } else if vm.isLoading {
            placeholder
        } else {
            EmptyView()
        }
    }

    private func content(for s: WeatherSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: s.symbolName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    iconPrimary(for: s),
                    iconSecondary(for: s)
                )
                .font(.system(size: 14, weight: .medium))
            VStack(alignment: .leading, spacing: 0) {
                Text(temperatureString(s.temperatureC))
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(s.locationName)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bubbleBackground)
        .overlay(bubbleStroke)
    }

    private var placeholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(.white.opacity(0.4))
                .font(.system(size: 13, weight: .medium))
            Text("—°")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bubbleBackground)
        .overlay(bubbleStroke)
    }

    /// Drop-down details revealed on hover: condition, rain chance, wind, UV.
    private func detailPanel(for s: WeatherSnapshot) -> some View {
        let cyan = Color(red: 0.0, green: 0.85, blue: 1.0)
        let rainPct = Int(s.precipitationProbability.rounded())
        let windKmh = Int(s.windSpeedKmh.rounded())
        return VStack(alignment: .leading, spacing: 4) {
            statRow(
                icon: s.symbolName,
                iconTint: iconPrimary(for: s),
                rotationDeg: 0,
                title: WeatherCode.text(for: s.weatherCode),
                subtitle: s.isDay ? L("Day", "白天") : L("Night", "夜晚")
            )
            Divider().overlay(Color.white.opacity(0.08))
            statRow(
                icon: "drop.fill",
                iconTint: RainScale.tint(s.precipitationProbability),
                rotationDeg: 0,
                title: "\(rainPct)% " + L("rain", "降水"),
                subtitle: RainScale.label(s.precipitationProbability)
            )
            Divider().overlay(Color.white.opacity(0.08))
            statRow(
                icon: "location.north.fill",
                iconTint: cyan,
                rotationDeg: s.windDirectionDeg + 180,    // arrow points where wind goes
                title: "\(windKmh) km/h " + WindScale.compass(s.windDirectionDeg),
                subtitle: WindScale.beaufort(s.windSpeedKmh)
            )
            Divider().overlay(Color.white.opacity(0.08))
            statRow(
                icon: "sun.max.trianglebadge.exclamationmark.fill",
                iconTint: UVScale.tint(s.uvIndex),
                rotationDeg: 0,
                title: L("UV", "紫外线") + " \(uvString(s.uvIndex))",
                subtitle: UVScale.label(s.uvIndex)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.70), Color.black.opacity(0.45)],
                    startPoint: .top, endPoint: .bottom
                ))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.4)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.30, blue: 0.75).opacity(0.40),
                            cyan.opacity(0.50)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        )
    }

    private func statRow(
        icon: String,
        iconTint: Color,
        rotationDeg: Double,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconTint)
                .rotationEffect(.degrees(rotationDeg))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
    }

    private func uvString(_ uv: Double) -> String {
        let r = uv.rounded()
        if r >= 1 { return String(Int(r)) }
        return String(format: "%.1f", uv)
    }

    private var bubbleBackground: some View {
        Capsule(style: .continuous)
            .fill(LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.30)],
                startPoint: .top, endPoint: .bottom
            ))
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
            )
    }

    private var bubbleStroke: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.30, blue: 0.75).opacity(0.45),
                        Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.55)
                    ],
                    startPoint: .leading, endPoint: .trailing
                ),
                lineWidth: 0.8
            )
    }

    private func iconPrimary(for s: WeatherSnapshot) -> Color {
        switch s.symbolName {
        case "sun.max.fill", "moon.stars.fill", "moon.fill":
            return Color(red: 1.0, green: 0.82, blue: 0.35)
        case "cloud.bolt.rain.fill":
            return Color(red: 1.0, green: 0.85, blue: 0.30)
        case "snowflake", "cloud.snow.fill":
            return .white
        default:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        }
    }

    private func iconSecondary(for s: WeatherSnapshot) -> Color {
        Color.white.opacity(0.85)
    }

    private func temperatureString(_ c: Double) -> String {
        let rounded = Int(c.rounded())
        return "\(rounded)°"
    }
}
