
import Foundation
import UIKit


public enum SDRemoteConfigKey: String, CodingKey {
    case prompt
    case negative_prompt
    case hr_upscaler
}

open class SDRemoteConfig: @unchecked Sendable {
    public var prompt: String? = nil
    public var negative_prompt: String? = nil
    public var hr_upscaler: String? = nil

    public init() {}
}
