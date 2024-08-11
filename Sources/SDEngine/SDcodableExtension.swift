

import Foundation

import fXDKit


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
    var args: Dictionary<String, Any?>? { get }
    static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self?
}
