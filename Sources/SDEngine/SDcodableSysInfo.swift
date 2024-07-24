

import Foundation


public struct SDcodableSysInfo: Codable {
	var Extensions: [SDcodableExtension]? = nil

	public var Config: SDcodableConfig? = nil
	public struct SDcodableConfig: Codable {
		public var outdir_samples: String? = nil

		public var sd_checkpoint_hash: String? = nil
		var sd_model_checkpoint: String? = nil

        public var sd_vae: String? = nil
	}
}


extension SDcodableSysInfo {
	public var extensionNames: Set<SDExtensionName>? {
		var extensionNames: Set<SDExtensionName> = []

		for sdExtension in self.Extensions ?? [] {
			guard sdExtension.name != nil,
				  let availableName = SDExtensionName(rawValue: sdExtension.name!) else {
				continue
			}

			extensionNames.insert(availableName)
		}

		return extensionNames.count > 0 ? extensionNames : nil
	}
}

extension SDcodableSysInfo {
	public func isEnabled(_ extensionCase: SDExtensionName) -> Bool {
		return extensionNames?.contains(extensionCase) ?? false
	}
}
