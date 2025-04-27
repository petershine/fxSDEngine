
import Foundation
import UIKit


public enum SDRemoteConfigKey: String, CodingKey {
    case prompt
    case hr_upscaler
}

@Observable
open class SDRemoteConfig: @unchecked Sendable {
    public var prompt: String? = nil
    public var hr_upscaler: String? = nil

    public init(prompt: String? = nil, hr_upscaler: String? = "R-ESRGAN 4x+") {
        self.prompt = prompt
        self.hr_upscaler = hr_upscaler
    }
}
