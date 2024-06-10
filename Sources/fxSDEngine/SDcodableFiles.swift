

import Foundation


struct SDcodableFiles: Codable {
	var files: [SDcodableFile?]? = nil
}

struct SDcodableFile: Codable {
	var type: String? = nil
	var size: String? = nil
	var name: String? = nil
	var fullpath: String? = nil
	var is_under_scanned_path: Bool? = nil
	var date: String? = nil
	var created_time: String? = nil
}

extension SDcodableFile {
	func updated_time() -> Date? {
		guard date != nil else {
			return nil
		}

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return dateFormatter.date(from:date!)
	}
}

