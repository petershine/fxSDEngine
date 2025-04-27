
import Foundation
import UIKit


public enum SDRemoteConfigKey: String, CodingKey {
    case hr_upscaler
}

@Observable
open class SDRemoteConfig: @unchecked Sendable {
    public var hr_upscaler: String? = nil

    public init(hr_upscaler: String? = "R-ESRGAN 4x+") {
        self.hr_upscaler = hr_upscaler
    }
}
