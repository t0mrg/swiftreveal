import Foundation

public enum FontScaling {
    public static let range: ClosedRange<Double> = 0.25...4
    public static func effective(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return 1 }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}
