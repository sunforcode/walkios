import Foundation

public enum PersonalTripWeatherValidator {
    private static let confidenceStatuses = Set([
        "unknown",
        "missing",
        "pending_verification",
        "stale",
        "unavailable",
    ])

     public static func isValid(
        _ weather: PersonalTripWeather,
        tripID: String,
        revision: String
    ) -> Bool {
        guard weather.tripID == tripID,
              weather.revision == revision,
              !weather.days.isEmpty else {
            return false
        }

        var dayIDs = Set<String>()
        var forecastsByID: [String: WeatherForecast] = [:]
        for (index, day) in weather.days.enumerated() {
            guard day.dayNumber == index + 1,
                  isNonEmpty(day.tripDayID),
                  dayIDs.insert(day.tripDayID).inserted,
                  !day.weatherAssociations.isEmpty,
                  isValidAssociations(
                      day.weatherAssociations,
                      date: day.date,
                      forecastsByID: &forecastsByID
                  ) else {
                return false
            }
        }
        return true
    }

    private static func isValidAssociations(
        _ associations: [TripWeatherAssociation],
        date: LocalDate,
        forecastsByID: inout [String: WeatherForecast]
    ) -> Bool {
        var identities = Set<String>()
        var previousSequence = 0

        for association in associations {
            guard association.sequence > previousSequence,
                  isNonEmpty(association.associationIdentity),
                  identities.insert(association.associationIdentity).inserted,
                  isValidLocation(association.targetLocation),
                  let targetStart = instantDate(association.targetPeriodStart),
                  let targetEnd = instantDate(association.targetPeriodEnd),
                  targetStart < targetEnd,
                  isInsideBusinessDate(start: targetStart, end: targetEnd, date: date),
                  isValidScope(association),
                  isValidForecastCombination(association),
                  isValidConfidence(association.forecastConfidence, allowsMetadata: false) else {
                return false
            }
            previousSequence = association.sequence

            guard let forecast = association.forecast else { continue }
            guard isValidForecast(
                forecast,
                targetLocation: association.targetLocation,
                targetStart: targetStart,
                targetEnd: targetEnd
            ) else {
                return false
            }
            if let existing = forecastsByID[forecast.identity], existing != forecast {
                return false
            }
            forecastsByID[forecast.identity] = forecast
        }
        return true
    }

    private static func isValidScope(_ association: TripWeatherAssociation) -> Bool {
        switch association.scope {
        case .day:
            return association.hikeActionIdentity == nil
        case .hikeAction:
            return isNonEmpty(association.hikeActionIdentity)
        }
    }

    private static func isValidForecastCombination(_ association: TripWeatherAssociation) -> Bool {
        guard let confidence = association.forecastConfidence else {
            return association.forecast != nil
        }
        switch confidence.status {
        case "pending_verification", "stale":
            return association.forecast != nil
        case "unavailable":
            return association.forecast == nil
        case "unknown", "missing":
            return true
        default:
            return false
        }
    }

    private static func isValidForecast(
        _ forecast: WeatherForecast,
        targetLocation: WeatherLocation,
        targetStart: Date,
        targetEnd: Date
    ) -> Bool {
        guard isNonEmpty(forecast.identity),
              isValidLocation(forecast.location),
              forecast.location.position == targetLocation.position,
              forecast.source.map(isNonEmpty) ?? true,
              forecast.publishedAt.map({ instantDate($0) != nil }) ?? true,
              !forecast.periods.isEmpty else {
            return false
        }

        var previousEnd: Date?
        var overlapsTarget = false
        for period in forecast.periods {
            guard let periodStart = instantDate(period.periodStart),
                  let periodEnd = instantDate(period.periodEnd),
                  periodStart < periodEnd,
                  previousEnd.map({ $0 <= periodStart }) ?? true,
                  isValidPeriod(period) else {
                return false
            }
            overlapsTarget = overlapsTarget || (periodStart < targetEnd && periodEnd > targetStart)
            previousEnd = periodEnd
        }
        return overlapsTarget
    }

    private static func isValidPeriod(_ period: WeatherForecastPeriod) -> Bool {
        let values: [Bool?] = [
            period.condition.map {
                isValidQualified($0) { isNonEmpty($0.description) }
            },
            period.temperatureRange.map {
                isValidQualified($0) { range in
                    guard range.low != nil || range.high != nil,
                          range.low.map(\.isFinite) ?? true,
                          range.high.map(\.isFinite) ?? true else {
                        return false
                    }
                    return (range.low.flatMap { low in range.high.map { low <= $0 } }) ?? true
                }
            },
            period.precipitation.map {
                isValidQualified($0) { precipitation in
                    let hasValue = precipitation.description != nil
                        || precipitation.probability != nil
                        || precipitation.amount != nil
                    return hasValue
                        && (precipitation.description.map(isNonEmpty) ?? true)
                        && (precipitation.probability.map { $0.isFinite && (0...1).contains($0) } ?? true)
                        && (precipitation.amount.map { $0.millimeters.isFinite && $0.millimeters >= 0 } ?? true)
                }
            },
            period.wind.map {
                isValidQualified($0) { wind in
                    let hasValue = wind.description != nil
                        || wind.averageSpeed != nil
                        || wind.gustSpeed != nil
                        || wind.direction != nil
                    guard hasValue,
                          wind.description.map(isNonEmpty) ?? true,
                          wind.direction.map(isNonEmpty) ?? true,
                          wind.averageSpeed.map({ $0.metersPerSecond.isFinite && $0.metersPerSecond >= 0 }) ?? true,
                          wind.gustSpeed.map({ $0.metersPerSecond.isFinite && $0.metersPerSecond >= 0 }) ?? true else {
                        return false
                    }
                    return (wind.averageSpeed.flatMap { average in
                        wind.gustSpeed.map { $0.metersPerSecond >= average.metersPerSecond }
                    }) ?? true
                }
            },
        ]
        return values.contains(true) && !values.contains(false)
    }

    private static func isValidQualified<Value>(
        _ qualified: WeatherQualifiedValue<Value>,
        valueIsValid: (Value) -> Bool
    ) -> Bool where Value: Codable & Equatable {
        guard qualified.value != nil || qualified.confidence != nil,
              isValidConfidence(qualified.confidence, allowsMetadata: false) else {
            return false
        }
        if let value = qualified.value, !valueIsValid(value) { return false }
        switch qualified.confidence?.status {
        case "pending_verification", "stale":
            return qualified.value != nil
        case "unavailable":
            return qualified.value == nil
        default:
            return true
        }
    }

    private static func isValidConfidence(
        _ confidence: InformationConfidence?,
        allowsMetadata: Bool
    ) -> Bool {
        guard let confidence else { return true }
        return confidenceStatuses.contains(confidence.status)
            && confidence.category == .dynamicExternalInformation
            && (allowsMetadata || (confidence.source == nil && confidence.updatedAt == nil))
    }

    private static func isValidLocation(_ location: WeatherLocation) -> Bool {
        location.position.latitude.isFinite
            && (-90...90).contains(location.position.latitude)
            && location.position.longitude.isFinite
            && (-180...180).contains(location.position.longitude)
            && isNonEmpty(location.position.referenceSystem)
            && (location.name.map(isNonEmpty) ?? true)
    }

    private static func isInsideBusinessDate(start: Date, end: Date, date: LocalDate) -> Bool {
        guard let dayStart = date.dateAtStartOfDay,
              let dayEnd = Calendar.business.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        return start >= dayStart && end <= dayEnd
    }

    private static func isNonEmpty(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let instantFormatter = ISO8601DateFormatter()
    private static let instantWithFractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func instantDate(_ instant: Instant) -> Date? {
        // 后端 epoch 时间转出的 ISO 字符串可能带毫秒小数，需要与小数秒格式兼容。
        instantWithFractionalSecondsFormatter.date(from: instant.rawValue)
            ?? instantFormatter.date(from: instant.rawValue)
    }
}
