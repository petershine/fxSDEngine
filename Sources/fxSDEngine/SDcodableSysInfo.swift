

import Foundation


public struct SDcodableSysInfo: Codable {
	var Extensions: [SDcodableExtension]? = nil

	var Config: SDcodableConfig? = nil
	struct SDcodableConfig: Codable {
		var outdir_samples: String? = nil
		var SCUNET_tile: Int? = nil
		var SCUNET_tile_overlap: Int? = nil
		var SWIN_tile: Int? = nil
		var SWIN_tile_overlap: Int? = nil
		var SWIN_torch_compile: Bool? = nil
		var hypertile_enable_unet: Bool? = nil
		var hypertile_enable_unet_secondpass: Bool? = nil
		var hypertile_enable_vae: Bool? = nil
		var hypertile_max_depth_unet: Int? = nil
		var hypertile_max_depth_vae: Int? = nil
		var hypertile_max_tile_unet: Int? = nil
		var hypertile_max_tile_vae: Int? = nil
		var hypertile_swap_size_unet: Int? = nil
		var hypertile_swap_size_vae: Int? = nil
		var ldsr_cached: Bool? = nil
		var ldsr_steps: Int? = nil
		var sd_checkpoint_hash: String? = nil
		var sd_model_checkpoint: String? = nil
	}
}

extension SDcodableSysInfo {
	public func generationFolder() -> String? {
		return Config?.outdir_samples
	}
}


extension SDcodableSysInfo {
	func availableExtensionNames() -> Set<SDExtensionName>? {
		var availableNames: Set<SDExtensionName> = []

		for on_script in self.Extensions ?? [] {
			guard on_script.name != nil,
				  let extensionName = SDExtensionName(rawValue: on_script.name!) else {
				continue
			}

			availableNames.insert(extensionName)
		}

		return availableNames.count > 0 ? availableNames : nil
	}

	private func available_scripts() -> Dictionary<String, Any?> {
		guard let availableNames = availableExtensionNames() else {
			return [:]
		}


		var alwayson_scripts: Dictionary<String, Any?> = [:]
		for extensionName in availableNames {
			if let args = extensionName.arguments() {
				alwayson_scripts[extensionName.rawValue] = args
			}
		}

		return alwayson_scripts
	}

	func alwayson_scripts(extensionNames: Set<SDExtensionName>?) -> Dictionary<String, Any?> {
		let available_scripts = available_scripts()
		guard available_scripts.count > 0 else {
			return [:]
		}


		var alwayson_scripts: Dictionary<String, Any?> = [:]
		for extensionName in extensionNames ?? [] {
			if let args = alwayson_scripts[extensionName.rawValue] {
				alwayson_scripts[extensionName.rawValue] = args
			}
		}

		return alwayson_scripts
	}
}
