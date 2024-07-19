

import Foundation


public struct SDcodableSysInfo: Codable {
	var Extensions: [SDcodableExtension]? = nil

	public var Config: SDcodableConfig? = nil
	public struct SDcodableConfig: Codable {
		public var outdir_samples: String? = nil

		public var sd_checkpoint_hash: String? = nil
		public var sd_model_checkpoint: String? = nil
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

	fileprivate var allExtensionArgs: Dictionary<String, Any?>? {
		var allArgs: Dictionary<String, Any?> = [:]

		for extensionName in extensionNames ?? [] {
			if let args = extensionName.arguments() {
				allArgs[extensionName.rawValue] = args
			}
		}

		return (allArgs.count > 0) ? allArgs : nil
	}

	func alwayson_scripts(extensionNames: Set<SDExtensionName>?) -> Dictionary<String, Any?> {
		guard let allExtensionArgs = allExtensionArgs,
			  allExtensionArgs.count > 0 else {
			return [:]
		}


		let alwayson_scripts = allExtensionArgs.filter {
			if let selectedName = SDExtensionName(rawValue: $0.key) {
				return extensionNames?.contains(selectedName) ?? false
			}
			return false
		}

		return alwayson_scripts
	}
}

extension SDcodableSysInfo {
	public func isEnabled(_ extensionCase: SDExtensionName) -> Bool {
		return extensionNames?.contains(extensionCase) ?? false
	}
}
