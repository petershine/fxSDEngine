

import Foundation

import fXDKit


public struct SDextensionControlNet: Codable {
    public init(from decoder: any Decoder) throws {
    }
}


extension SDextensionControlNet: SDprotocolExtension {
    public var args: Dictionary<String, Any?>? {
        return nil
    }

    public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {
        return nil
    }
}
