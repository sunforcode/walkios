import Foundation

/// 天气模型
struct Weather: Codable, Equatable {
    let temperature: Double?
    let feelsLike: Double?
    let humidity: Int?
    let windSpeed: Double?
    let description: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case temperature
        case feelsLike = "feels_like"
        case humidity
        case windSpeed = "wind_speed"
        case description
        case icon
    }

    /// 温度显示
    var temperatureDescription: String {
        guard let temp = temperature else { return "--" }
        return "\(Int(temp))°C"
    }
}
