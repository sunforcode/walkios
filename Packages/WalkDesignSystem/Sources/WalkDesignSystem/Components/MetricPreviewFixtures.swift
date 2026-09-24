#if DEBUG
/// MetricItem / MetricGroup 预览与组件目录共用的样例数据。
 public enum MetricPreviewFixtures {
    public static let completeMetrics: [MetricItemModel] = [
        MetricItemModel(id: "distance", value: "12.1", unit: "km", label: "距离"),
        MetricItemModel(id: "ascent", value: "600", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "duration", value: "约 5 h 20 min", label: "预计用时"),
    ]

    public static let missingMetrics: [MetricItemModel] = [
        MetricItemModel(id: "distance", value: nil, unit: "km", label: "距离"),
        MetricItemModel(id: "ascent", value: nil, unit: "m", label: "累计爬升"),
        MetricItemModel(id: "duration", value: "约 5 h 20 min", label: "预计用时"),
    ]
}
#endif
