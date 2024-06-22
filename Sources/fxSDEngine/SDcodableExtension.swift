

import Foundation

import fXDKit


public struct SDcodableExtension: Codable {
	var branch: String? = nil
	var name: String? = nil
	var path: String? = nil
	var remote: String? = nil
	var version: String? = nil
}

public enum SDExtensionName: String {
	case adetailer
}

extension SDExtensionName {
	func arguments() -> Dictionary<String, Any?>? {
		var args: Dictionary<String, Any?>? = nil
		do {
			switch self {
				case .adetailer:
					args = [
						"args" : [
							true,
							false,
							try JSONEncoder().encode(SDextensionADetailer()).jsonObject() ?? [:],
						]
					]
			}
		}
		catch {	fxd_log()
			fxdPrint(error)
		}
		return args
	}
}

extension SDcodableExtension {
	public static func availableExtensionNames(extensions: [Self]?) -> Set<SDExtensionName>? {
		var availableNames: Set<SDExtensionName> = []

		for on_script in extensions ?? [] {
			guard on_script.name != nil,
				  let extensionName = SDExtensionName(rawValue: on_script.name!) else {
				continue
			}

			availableNames.insert(extensionName)
		}

		return availableNames.count > 0 ? availableNames : nil
	}

	private static func alwayson_scripts(extensions: [Self]?) -> Dictionary<String, Any?> {
		guard let availableNames = Self.availableExtensionNames(extensions: extensions) else {
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

	static func selected_scripts(extensions: [Self]?, selectedExtensions: Set<SDExtensionName>?) -> Dictionary<String, Any?> {
		let alwayson_scripts = Self.alwayson_scripts(extensions: extensions)
		guard alwayson_scripts.count > 0 else {
			return [:]
		}


		var selected_scripts: Dictionary<String, Any?> = [:]
		for extensionName in selectedExtensions ?? [] {
			if let args = alwayson_scripts[extensionName.rawValue] {
				selected_scripts[extensionName.rawValue] = args
			}
		}

		return selected_scripts
	}
}

/*
 Extensions =     (
			 {
		 branch = main;
		 name = adetailer;
		 path = "/Volumes/zzzz/_zSD/stable-diffusion-webui/extensions/adetailer";
		 remote = "https://github.com/Bing-su/adetailer";
		 version = a89c01d3;
	 },

 */
struct SDextensionADetailer: Codable {
	var ad_cfg_scale: Int = 7
	var ad_checkpoint: String = "Use same checkpoint"
	var ad_clip_skip: Int = 1
	var ad_confidence: Double = 0.3
	var ad_controlnet_guidance_end: Int = 1
	var ad_controlnet_guidance_start: Int = 0
	var ad_controlnet_model: String = "None"
	var ad_controlnet_module: String = "None"
	var ad_controlnet_weight: Int = 1
	var ad_denoising_strength: Double = 0.4
	var ad_dilate_erode: Int = 4
	var ad_inpaint_height: Int = 512
	var ad_inpaint_only_masked: Bool = true
	var ad_inpaint_only_masked_padding: Int = 32
	var ad_inpaint_width: Int = 512
	var ad_mask_blur: Int = 4
	var ad_mask_k_largest: Int = 2
	var ad_mask_max_ratio: Int = 1
	var ad_mask_merge_invert: String = "None"
	var ad_mask_min_ratio: Int = 0
	var ad_model: String = "face_yolov8n.pt"
	var ad_model_classes: String = ""
	var ad_negative_prompt: String = ""
	var ad_noise_multiplier: Int = 1
	var ad_prompt: String = ""
	var ad_restore_face: Bool = false
	var ad_sampler: String = "Use same sampler"
	var ad_scheduler: String = "Use same scheduler"
	var ad_steps: Int = 28
	var ad_tab_enable: Bool = true
	var ad_use_cfg_scale: Bool = false
	var ad_use_checkpoint: Bool = false
	var ad_use_clip_skip: Bool = false
	var ad_use_inpaint_width_height: Bool = false
	var ad_use_noise_multiplier: Bool = false
	var ad_use_sampler: Bool = false
	var ad_use_steps: Bool = false
	var ad_use_vae: Bool = false
	var ad_vae: String = "Use same VAE"
	var ad_x_offset: Int = 0
	var ad_y_offset: Int = 0
	var is_api: Array<Bool> = []
}
