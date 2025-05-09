
import Foundation
import UIKit

import fXDKit

public let DIMENSION_OPTIMAL_MIN: Double = 798.0
public let DIMENSION_OPTIMAL_MAX: Double = 1216.0

public enum SDDefaultConfigKey: String, CaseIterable {
    case allowDemoActivation

    case hr_upscaler
    case prompt
    case negative_prompt
}


@Observable
open class SDDefaultConfig: @unchecked Sendable {
    public var allowDemoActivation: Bool = false

    public var hr_upscaler: String? = nil
    public var prompt: String? = nil
    public var negative_prompt: String? = nil

    
    public init(
        allowDemoActivation: Bool = false,

        hr_upscaler: String? = nil,
        prompt: String? = nil,
        negative_prompt: String? = nil
    ) {
        self.allowDemoActivation = allowDemoActivation

        self.hr_upscaler = hr_upscaler
        self.prompt = prompt
        self.negative_prompt = negative_prompt
    }
}
