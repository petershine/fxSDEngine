

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
	public var updated_time: Date? {
		guard date != nil else {
			return nil
		}

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return dateFormatter.date(from:date!)
	}
}

