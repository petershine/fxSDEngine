

import Foundation

import fXDKit


struct SDcodableExtension: Codable {
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
							try JSONDecoder().decode(SDextensionADetailer.self, from: "{}".data(using: .utf8) ?? Data()),
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


public struct SDextensionADetailer: Codable {
	var ad_confidence: Double = 0.3
	var ad_denoising_strength: Double = 0.3
	var ad_dilate_erode: Int = 4
	var ad_inpaint_only_masked: Bool = true
	var ad_inpaint_only_masked_padding: Int = 32
	var ad_mask_blur: Int = 4
	var ad_mask_k_largest: Int = 2
	var ad_model: String = "face_yolov8n.pt"

	var ad_cfg_scale: Int? = 7
	var ad_checkpoint: String? = "Use same checkpoint"
	var ad_clip_skip: Int? = 1
	var ad_controlnet_guidance_end: Int? = 1
	var ad_controlnet_guidance_start: Int? = 0
	var ad_controlnet_model: String? = "None"
	var ad_controlnet_module: String? = "None"
	var ad_controlnet_weight: Int? = 1
	var ad_inpaint_height: Int? = 512
	var ad_inpaint_width: Int? = 512
	var ad_mask_max_ratio: Int? = 1
	var ad_mask_merge_invert: String? = "None"
	var ad_mask_min_ratio: Int? = 0
	var ad_model_classes: String? = ""
	var ad_negative_prompt: String? = ""
	var ad_noise_multiplier: Int? = 1
	var ad_prompt: String? = ""
	var ad_restore_face: Bool? = false
	var ad_sampler: String? = "Use same sampler"
	var ad_scheduler: String? = "Use same scheduler"
	var ad_steps: Int? = 28
	var ad_tab_enable: Bool? = true
	var ad_use_cfg_scale: Bool? = false
	var ad_use_checkpoint: Bool? = false
	var ad_use_clip_skip: Bool? = false
	var ad_use_inpaint_width_height: Bool? = false
	var ad_use_noise_multiplier: Bool? = false
	var ad_use_sampler: Bool? = false
	var ad_use_steps: Bool? = false
	var ad_use_vae: Bool? = false
	var ad_vae: String? = "Use same VAE"
	var ad_x_offset: Int? = 0
	var ad_y_offset: Int? = 0
	var is_api: Array<Bool?>? = []

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.ad_confidence = try container.decode(Double.self, forKey: .ad_confidence)
		self.ad_denoising_strength = try container.decode(Double.self, forKey: .ad_denoising_strength)
		self.ad_dilate_erode = try container.decode(Int.self, forKey: .ad_dilate_erode)
		self.ad_inpaint_only_masked = try container.decode(Bool.self, forKey: .ad_inpaint_only_masked)
		self.ad_inpaint_only_masked_padding = try container.decode(Int.self, forKey: .ad_inpaint_only_masked_padding)
		self.ad_mask_blur = try container.decode(Int.self, forKey: .ad_mask_blur)
		self.ad_mask_k_largest = try container.decode(Int.self, forKey: .ad_mask_k_largest)
		self.ad_model = try container.decode(String.self, forKey: .ad_model)
		
		self.ad_cfg_scale = try container.decodeIfPresent(Int.self, forKey: .ad_cfg_scale)
		self.ad_checkpoint = try container.decodeIfPresent(String.self, forKey: .ad_checkpoint)
		self.ad_clip_skip = try container.decodeIfPresent(Int.self, forKey: .ad_clip_skip)
		self.ad_controlnet_guidance_end = try container.decodeIfPresent(Int.self, forKey: .ad_controlnet_guidance_end)
		self.ad_controlnet_guidance_start = try container.decodeIfPresent(Int.self, forKey: .ad_controlnet_guidance_start)
		self.ad_controlnet_model = try container.decodeIfPresent(String.self, forKey: .ad_controlnet_model)
		self.ad_controlnet_module = try container.decodeIfPresent(String.self, forKey: .ad_controlnet_module)
		self.ad_controlnet_weight = try container.decodeIfPresent(Int.self, forKey: .ad_controlnet_weight)
		self.ad_inpaint_height = try container.decodeIfPresent(Int.self, forKey: .ad_inpaint_height)
		self.ad_inpaint_width = try container.decodeIfPresent(Int.self, forKey: .ad_inpaint_width)
		self.ad_mask_max_ratio = try container.decodeIfPresent(Int.self, forKey: .ad_mask_max_ratio)
		self.ad_mask_merge_invert = try container.decodeIfPresent(String.self, forKey: .ad_mask_merge_invert)
		self.ad_mask_min_ratio = try container.decodeIfPresent(Int.self, forKey: .ad_mask_min_ratio)
		self.ad_model_classes = try container.decodeIfPresent(String.self, forKey: .ad_model_classes)
		self.ad_negative_prompt = try container.decodeIfPresent(String.self, forKey: .ad_negative_prompt)
		self.ad_noise_multiplier = try container.decodeIfPresent(Int.self, forKey: .ad_noise_multiplier)
		self.ad_prompt = try container.decodeIfPresent(String.self, forKey: .ad_prompt)
		self.ad_restore_face = try container.decodeIfPresent(Bool.self, forKey: .ad_restore_face)
		self.ad_sampler = try container.decodeIfPresent(String.self, forKey: .ad_sampler)
		self.ad_scheduler = try container.decodeIfPresent(String.self, forKey: .ad_scheduler)
		self.ad_steps = try container.decodeIfPresent(Int.self, forKey: .ad_steps)
		self.ad_tab_enable = try container.decodeIfPresent(Bool.self, forKey: .ad_tab_enable)
		self.ad_use_cfg_scale = try container.decodeIfPresent(Bool.self, forKey: .ad_use_cfg_scale)
		self.ad_use_checkpoint = try container.decodeIfPresent(Bool.self, forKey: .ad_use_checkpoint)
		self.ad_use_clip_skip = try container.decodeIfPresent(Bool.self, forKey: .ad_use_clip_skip)
		self.ad_use_inpaint_width_height = try container.decodeIfPresent(Bool.self, forKey: .ad_use_inpaint_width_height)
		self.ad_use_noise_multiplier = try container.decodeIfPresent(Bool.self, forKey: .ad_use_noise_multiplier)
		self.ad_use_sampler = try container.decodeIfPresent(Bool.self, forKey: .ad_use_sampler)
		self.ad_use_steps = try container.decodeIfPresent(Bool.self, forKey: .ad_use_steps)
		self.ad_use_vae = try container.decodeIfPresent(Bool.self, forKey: .ad_use_vae)
		self.ad_vae = try container.decodeIfPresent(String.self, forKey: .ad_vae)
		self.ad_x_offset = try container.decodeIfPresent(Int.self, forKey: .ad_x_offset)
		self.ad_y_offset = try container.decodeIfPresent(Int.self, forKey: .ad_y_offset)
		self.is_api = try container.decodeIfPresent([Bool?].self, forKey: .is_api)
	}
}

extension SDextensionADetailer {
	public var args: Dictionary<String, Any?>? {
		var args: Dictionary<String, Any?>? = nil
		do {
			args = [
				"args" : [
					true,
					false,
					try JSONEncoder().encode(self).jsonDictionary() ?? [:],
				]
			]
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return args
	}
}
