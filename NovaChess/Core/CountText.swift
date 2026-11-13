import Foundation

public enum CountText {
    public static func value(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        "\(count) " + noun(count, singular, plural: plural)
    }
    public static func noun(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        (count == 1 || count == -1) ? singular : (plural ?? singular + "s")
    }
}
