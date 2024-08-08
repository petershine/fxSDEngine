

import Foundation

import fXDKit


public struct SDextensionControlNet: Codable {
    public init(from decoder: any Decoder) throws {
    }
}


extension SDextensionControlNet: SDprotocolExtension {
    public var args: Dictionary<String, Any?>? {
        var args: Dictionary<String, Any?>? = nil
        do {
            args = [
                "args" : [
                    try JSONEncoder().encode(self).jsonDictionary() ?? [:],
                ]
            ]
        }
        catch {    fxd_log()
            fxdPrint(error)
        }

        return args
    }
    
    public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {
        return nil
    }
}
