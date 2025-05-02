
import Foundation
import UIKit

import fXDKit


public enum SDDefaultConfigKey: String, CaseIterable {
    case hr_upscaler
    case prompt
    case negative_prompt
}


open class SDDefaultConfig: @unchecked Sendable {
    public var hr_upscaler: String? = nil
    public var prompt: String? = nil
    public var negative_prompt: String? = nil

    public init(hr_upscaler: String? = nil, prompt: String? = nil, negative_prompt: String? = nil) {
        self.hr_upscaler = hr_upscaler
        self.prompt = prompt
        self.negative_prompt = negative_prompt
    }
}
