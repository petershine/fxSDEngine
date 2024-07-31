

import Foundation
import UIKit


public struct SDcodableProgress: Codable {
	public var progress: Double? = nil
	var eta_relative: Date? = nil
	var textinfo: String? = nil

	public var current_image: String? = nil
	public var state: SDcodableState? = nil
}

public struct SDcodableState: Codable {
	var interrupted: Bool? = nil
	public var job: String? = nil
	public var job_count: Int? = nil
	public var job_no: Int? = nil
	public var job_timestamp: String? = nil
	public var sampling_step: Int? = nil
	public var sampling_steps: Int? = nil
	var skipped: Bool? = nil
	var stopping_generation: Bool? = nil
}

public extension SDcodableState {
    var isSystemBusy: Bool? {
        return !((job ?? "").isEmpty || interrupted ?? true)
    }
}
