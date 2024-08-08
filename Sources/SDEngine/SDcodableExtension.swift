

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

public protocol SDprotocolExtension: Hashable, Sendable, Codable {
    static func minimum() -> Self?

    var args: Dictionary<String, Any?>? { get }
    static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self?
}

extension SDprotocolExtension {
    public static func minimum() -> Self? {
        var minimumInstance: Self? = nil
        do {
            minimumInstance = try JSONDecoder().decode(Self.self, from: "{}".data(using: .utf8) ?? Data())
        }
        catch {    fxd_log()
            fxdPrint(error)
        }

        return minimumInstance
    }
}
