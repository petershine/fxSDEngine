
import Foundation
import UIKit

import fXDKit


fileprivate let DIMENSION_OPTIMAL_MIN: Double = 672.0
fileprivate let DIMENSION_OPTIMAL_MAX: Double = 1024.0


public enum SDDefaultConfigKey: String, CaseIterable {
    case allowDemoActivation

    case optimalMin
    case optimalMax

    case hr_upscaler
    case prompt
    case negative_prompt
}


@Observable
open class SDDefaultConfig: @unchecked Sendable {
    public var allowDemoActivation: Bool = false

    public var optimalMin: Double = DIMENSION_OPTIMAL_MIN
    public var optimalMax: Double = DIMENSION_OPTIMAL_MAX

    public var hr_upscaler: String? = nil
    public var prompt: String? = nil
    public var negative_prompt: String? = nil

    
    public init(
        allowDemoActivation: Bool = false,

        optimalMin: Double? = nil,
        optimalMax: Double? = nil,

        hr_upscaler: String? = nil,
        prompt: String? = nil,
        negative_prompt: String? = nil
    ) {
        self.allowDemoActivation = allowDemoActivation

        self.optimalMin = optimalMin ?? DIMENSION_OPTIMAL_MIN
        self.optimalMax = optimalMax ?? DIMENSION_OPTIMAL_MAX

        self.hr_upscaler = hr_upscaler
        self.prompt = prompt
        self.negative_prompt = negative_prompt
    }
}
