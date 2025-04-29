
import Foundation
import UIKit


public enum SDDefaultConfigKey: String, CodingKey {
    case prompt
    case negative_prompt
    case hr_upscaler
}

@Observable
open class SDDefaultConfig: @unchecked Sendable {
    public var prompt: String? = nil
    public var negative_prompt: String? = nil
    public var hr_upscaler: String? = nil

    public init() {}
}
