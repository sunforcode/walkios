import Foundation
import CoreLocation
import WalkData
import WalkDesignSystem

/// 定位服务
/// 封装 CLLocationManager，提供位置更新、权限管理和轨迹记录
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    /// 当前位置
    @Published var currentLocation: CLLocation?
    /// 授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// 是否正在记录轨迹
    @Published var isRecording = false
    /// 记录的轨迹点
    @Published var recordedLocations: [CLLocation] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - 权限请求

    /// 请求使用期间定位权限
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 请求始终定位权限（后台轨迹记录需要）
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - 定位控制

    /// 开始定位
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestWhenInUseAuthorization()
            return
        }
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 轨迹记录

    /// 开始记录轨迹
    func startRecording() {
        isRecording = true
        recordedLocations = []
        startUpdatingLocation()
    }

    /// 停止记录轨迹
    func stopRecording() {
        isRecording = false
        stopUpdatingLocation()
    }

    /// 清除轨迹
    func clearRecordedLocations() {
        recordedLocations = []
    }

    // MARK: - 轨迹数据

    /// 轨迹总距离（米）
    var totalDistance: Double {
        guard recordedLocations.count >= 2 else { return 0 }
        var distance: Double = 0
        for i in 1..<recordedLocations.count {
            distance += recordedLocations[i-1].distance(from: recordedLocations[i])
        }
        return distance
    }

    /// 总爬升（米）
    var totalAscent: Double {
        guard recordedLocations.count >= 2 else { return 0 }
        var ascent: Double = 0
        for i in 1..<recordedLocations.count {
            let delta = recordedLocations[i].altitude - recordedLocations[i-1].altitude
            if delta > 0 {
                ascent += delta
            }
        }
        return ascent
    }

    /// 轨迹时长（秒）
    var totalDuration: TimeInterval {
        guard let first = recordedLocations.first?.timestamp,
              let last = recordedLocations.last?.timestamp else { return 0 }
        return last.timeIntervalSince(first)
    }

    /// 转换为 CLLocationCoordinate2D 数组（用于地图显示）
    var coordinates: [CLLocationCoordinate2D] {
        recordedLocations.map { $0.coordinate }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        if isRecording {
            recordedLocations.append(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationService: didFailWithError - \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
