

import Foundation

import fXDKit


public protocol SDprotocolCodable: Codable {
    static func loaded(from fileURL: URL?) throws -> Self?
    static func minimum() -> Self?
}

public extension SDprotocolCodable {
    static func loaded(from fileURL: URL?) throws -> Self? {
        guard let fileURL else {
            return nil
        }

        do {
            let loaded = try Data(contentsOf: fileURL)
            return loaded.decode(Self.self)
        }
        catch {
            return Self.minimum()
        }
    }

    static func minimum() -> Self? {
        guard let minimumData = "{}".data(using: .utf8) else {
            return nil
        }

        var minimumInstance: Self? = nil
        do {
            minimumInstance = try JSONDecoder().decode(Self.self, from: minimumData)
        }
        catch {    fxd_log()
            fxdPrint(error)
        }

        return minimumInstance
    }
}
