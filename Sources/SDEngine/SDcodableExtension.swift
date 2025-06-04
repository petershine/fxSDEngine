import Foundation

struct SDcodableExtension: Codable {
	var branch: String?
	var name: String?
	var path: String?
	var remote: String?
	var version: String?
}

public enum SDExtensionName: String {
	case adetailer
    case controlnet
}

public protocol SDprotocolExtension: Codable {
    static func decoded(using jsonDictionary: inout [String: Any?]) -> Self?
    var args: [String: Any?]? { get }
    func configurations() -> [[String]]
}
