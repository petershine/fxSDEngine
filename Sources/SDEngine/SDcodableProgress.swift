import Foundation
import UIKit

public struct SDcodableProgress: Codable, Sendable {
	public var progress: Double?
	var eta_relative: Date?
	var textinfo: String?

	public var current_image: String?
	public var state: SDcodableState?
}

public struct SDcodableState: Codable, Sendable {
	var interrupted: Bool?
	public var job: String?
	public var job_count: Int?
	public var job_no: Int?
	public var job_timestamp: String?
	public var sampling_step: Int?
	public var sampling_steps: Int?
	var skipped: Bool?
	var stopping_generation: Bool?
}

public extension SDcodableState {
    var isProgressing: Bool? {
        return !((job ?? "").isEmpty || interrupted ?? true)
    }

    var formattedTimestamp: String? {
        guard let job_timestamp else {
            return nil
        }

        let sourceFormatter = DateFormatter()
        sourceFormatter.dateFormat = "yyyyMMddHHmmss"
        guard let job_date = sourceFormatter.date(from: job_timestamp) else {
            return nil
        }

        let targetFormatter = DateFormatter()
        targetFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return targetFormatter.string(from: job_date)
    }
}
