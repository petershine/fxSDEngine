

import Foundation


struct SDcodableExtension: Codable {
	var branch: String? = nil
	var name: String? = nil
	var path: String? = nil
	var remote: String? = nil
	var version: String? = nil
}

public enum SDExtensionName: String {
	case adetailer
    case controlnet
}

public protocol SDprotocolExtension: Codable {
    static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self?
    var args: Dictionary<String, Any?>? { get }
    func configurations() -> [[String]]
}
