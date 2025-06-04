import Foundation

public struct SDcodableFiles: Codable {
	public var files: [SDcodableFile?]?
}

public struct SDcodableFile: Codable {
	public var type: String?
	var size: String?
	var name: String?
	public var fullpath: String?
	var is_under_scanned_path: Bool?
	var date: String?
	var created_time: String?
}

extension SDcodableFile {
    var updated_time: Date? {
        guard date != nil else {
            return nil
        }

        let targetFormatter = DateFormatter()
        targetFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return targetFormatter.date(from: date!)
    }
}
