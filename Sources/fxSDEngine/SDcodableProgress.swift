

import Foundation


public struct SDcodableProgress: Codable {
	public var progress: Double? = nil
	var eta_relative: Date? = nil
	var textinfo: String? = nil

	var current_image: String? = nil
	public var state: SDcodableState? = nil
}

public struct SDcodableState: Codable {
	var interrupted: Bool? = nil
	public var job: String? = nil
	var job_count: Int? = nil
	var job_no: Int? = nil
	var job_timestamp: String? = nil
	var sampling_step: Int? = nil
	var sampling_steps: Int? = nil
	var skipped: Bool? = nil
	var stopping_generation: Bool? = nil
}

extension SDcodableState {
	public func isJobRunning() -> Bool {
		return !((job ?? "").isEmpty || interrupted ?? true)
	}
}
