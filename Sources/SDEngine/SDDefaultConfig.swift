import Foundation
import UIKit

import fXDKit

private let DIMENSION_OPTIMAL_MIN: Double = 672.0
private let DIMENSION_OPTIMAL_MAX: Double = 1024.0

public enum SDDefaultConfigKey: String, CaseIterable {
    case allowDemoActivation

    case optimalMin
    case optimalMax

    case hr_second_pass_steps
    case hr_upscaler

    case prompt
    case negative_prompt
}

@Observable
open class SDDefaultConfig {
    public var allowDemoActivation: Bool = false

    public var optimalMin: Double = DIMENSION_OPTIMAL_MIN
    public var optimalMax: Double = DIMENSION_OPTIMAL_MAX

    public var hr_second_pass_steps: Int = 5
    public var hr_upscaler: String?
    
    public var prompt: String?
    public var negative_prompt: String?

    public init() {
    }
}
