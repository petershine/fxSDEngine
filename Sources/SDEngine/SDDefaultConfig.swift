
import Foundation
import UIKit
import Combine

import fXDKit


public enum SDDefaultConfigKey: String, CaseIterable {
    case hr_upscaler
    case prompt
    case negative_prompt
}


@Observable
open class SDDefaultConfig: @unchecked Sendable {
    public var hr_upscaler: String? = nil
    public var prompt: String? = nil
    public var negative_prompt: String? = nil

    public var cancellables: [AnyCancellable?] = []
    public var handler: (([SDDefaultConfigKey: Any]?) -> Void)? = nil

    public init() {
        handler = {
            receivedConfig in

            guard let receivedConfig else {
                return
            }

            
            for key in SDDefaultConfigKey.allCases {
                guard let value = receivedConfig[key] as? String,
                      !value.isEmpty else {
                    continue
                }

                switch key {
                    case .hr_upscaler:
                        self.hr_upscaler = value

                    case .prompt:
                        self.prompt = value

                    case .negative_prompt:
                        self.negative_prompt = value
                }
            }

            fxd_log()
            fxdPrint("hr_upscaler: \(self.hr_upscaler ?? "(not received)")")
            fxdPrint("prompt: \(self.prompt ?? "(not received)")")
            fxdPrint("negative_prompt: \(self.negative_prompt ?? "(not received)")")

            fxdPrint("receivedConfig: \(receivedConfig)")
        }
    }
}
