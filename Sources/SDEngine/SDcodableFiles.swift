

import Foundation


public struct SDcodableFiles: Codable {
	public var files: [SDcodableFile?]? = nil
}

public struct SDcodableFile: Codable {
	public var type: String? = nil
	var size: String? = nil
	var name: String? = nil
	public var fullpath: String? = nil
	var is_under_scanned_path: Bool? = nil
	var date: String? = nil
	var created_time: String? = nil
}

extension SDcodableFile {
    var updated_time: Date? {
        guard date != nil else {
            return nil
        }

        let targetFormatter = DateFormatter()
        targetFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return targetFormatter.date(from:date!)
    }
}
