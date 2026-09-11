import Foundation

/// 天气模型
public struct Weather: Codable, Equatable {
     public let temperature: Double?
     public let feelsLike: Double?
     public let humidity: Int?
     public let windSpeed: Double?
     public let description: String?
     public let icon: String?

    public enum CodingKeys: String, CodingKey {
        case temperature
        case feelsLike = "feels_like"
        case humidity
        case windSpeed = "wind_speed"
        case description
        case icon
    }

    /// 温度显示
     public var temperatureDescription: String {
        guard let temp = temperature else { return "--" }
        return "\(Int(temp))°C"
    }

    public init(
        temperature: Double?,
        feelsLike: Double?,
        humidity: Int?,
        windSpeed: Double?,
        description: String?,
        icon: String?
    ) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.description = description
        self.icon = icon
    }
}
