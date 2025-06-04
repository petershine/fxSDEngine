import Foundation

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
            return (try Data(contentsOf: fileURL)).decode(Self.self)
        } catch {
            return Self.minimum()
        }
    }

    static func minimum() -> Self? {
        guard let minimumData = "{}".data(using: .utf8) else {
            return nil
        }

        var minimumInstance: Self?
        do {
            minimumInstance = try JSONDecoder().decode(Self.self, from: minimumData)
        } catch {
        }

        return minimumInstance
    }
}
