

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


public struct SDextensionADetailer: Codable {
	var ad_confidence: Double
	var ad_denoising_strength: Double
	var ad_dilate_erode: Int
	var ad_inpaint_only_masked: Bool
	var ad_inpaint_only_masked_padding: Int
	var ad_mask_blur: Int
	var ad_mask_k_largest: Int
	var ad_model: String

	var ad_cfg_scale: Int
	var ad_checkpoint: String
	var ad_clip_skip: Int
	var ad_controlnet_guidance_end: Int
	var ad_controlnet_guidance_start: Int
	var ad_controlnet_model: String
	var ad_controlnet_module: String
	var ad_controlnet_weight: Int
	var ad_inpaint_height: Int
	var ad_inpaint_width: Int
	var ad_mask_max_ratio: Int
	var ad_mask_merge_invert: String
	var ad_mask_min_ratio: Int
	var ad_model_classes: String
	var ad_negative_prompt: String
	var ad_noise_multiplier: Int
	var ad_prompt: String
	var ad_restore_face: Bool
	var ad_sampler: String
	var ad_scheduler: String
	var ad_steps: Int
	var ad_tab_enable: Bool
	var ad_use_cfg_scale: Bool
	var ad_use_checkpoint: Bool
	var ad_use_clip_skip: Bool
	var ad_use_inpaint_width_height: Bool
	var ad_use_noise_multiplier: Bool
	var ad_use_sampler: Bool
	var ad_use_steps: Bool
	var ad_use_vae: Bool
	var ad_vae: String
	var ad_x_offset: Int
	var ad_y_offset: Int
	var is_api: Array<Bool?>

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.ad_confidence = try container.decodeIfPresent(Double.self, forKey: .ad_confidence) ?? 0.3
		self.ad_denoising_strength = try container.decodeIfPresent(Double.self, forKey: .ad_denoising_strength) ?? 0.3
		self.ad_dilate_erode = try container.decodeIfPresent(Int.self, forKey: .ad_dilate_erode) ?? 4
		self.ad_inpaint_only_masked = try container.decodeIfPresent(Bool.self, forKey: .ad_inpaint_only_masked) ?? true
		self.ad_inpaint_only_masked_padding = try container.decodeIfPresent(Int.self, forKey: .ad_inpaint_only_masked_padding) ?? 31
		self.ad_mask_blur = try container.decodeIfPresent(Int.self, forKey: .ad_mask_blur) ?? 4
		self.ad_mask_k_largest = try container.decodeIfPresent(Int.self, forKey: .ad_mask_k_largest) ?? 2
		self.ad_model = try container.decodeIfPresent(String.self, forKey: .ad_model) ?? "face_yolov8n.pt"

		self.ad_cfg_scale = try container.decodeIfPresent(Int.self, forKey: .ad_cfg_scale) ?? 7
		self.ad_checkpoint = try container.decodeIfPresent(String.self, forKey: .ad_checkpoint) ?? "Use same checkpoint"
		self.ad_clip_skip = try container.decodeIfPresent(Int.self, forKey: .ad_clip_skip) ?? 1
		self.ad_controlnet_guidance_end = try container.decodeIfPresent(Int.self, forKey: .ad_controlnet_guidance_end) ?? 1
		self.ad_controlnet_guidance_start = try container.decodeIfPresent(Int.self, forKey: .ad_controlnet_guidance_start) ?? 0
		self.ad_controlnet_model = try container.decodeIfPresent(String.self, forKey: .ad_controlnet_model) ?? "None"
		self.ad_controlnet_module = try container.decodeIfPresent(String.self, forKey: .ad_controlnet_module) ?? "None"
		self.ad_controlnet_weight = try container.decodeIfPresent(Int.self, forKey: .ad_controlnet_weight) ?? 1
		self.ad_inpaint_height = try container.decodeIfPresent(Int.self, forKey: .ad_inpaint_height) ?? 512
		self.ad_inpaint_width = try container.decodeIfPresent(Int.self, forKey: .ad_inpaint_width) ?? 512
		self.ad_mask_max_ratio = try container.decodeIfPresent(Int.self, forKey: .ad_mask_max_ratio) ?? 1
		self.ad_mask_merge_invert = try container.decodeIfPresent(String.self, forKey: .ad_mask_merge_invert) ?? "None"
		self.ad_mask_min_ratio = try container.decodeIfPresent(Int.self, forKey: .ad_mask_min_ratio) ?? 0
		self.ad_model_classes = try container.decodeIfPresent(String.self, forKey: .ad_model_classes) ?? ""
		self.ad_negative_prompt = try container.decodeIfPresent(String.self, forKey: .ad_negative_prompt) ?? ""
		self.ad_noise_multiplier = try container.decodeIfPresent(Int.self, forKey: .ad_noise_multiplier) ?? 1
		self.ad_prompt = try container.decodeIfPresent(String.self, forKey: .ad_prompt) ?? ""
		self.ad_restore_face = try container.decodeIfPresent(Bool.self, forKey: .ad_restore_face) ?? false
		self.ad_sampler = try container.decodeIfPresent(String.self, forKey: .ad_sampler) ?? "Use same sampler"
		self.ad_scheduler = try container.decodeIfPresent(String.self, forKey: .ad_scheduler) ?? "Use same scheduler"
		self.ad_steps = try container.decodeIfPresent(Int.self, forKey: .ad_steps) ?? 28
		self.ad_tab_enable = try container.decodeIfPresent(Bool.self, forKey: .ad_tab_enable) ?? true
		self.ad_use_cfg_scale = try container.decodeIfPresent(Bool.self, forKey: .ad_use_cfg_scale) ?? false
		self.ad_use_checkpoint = try container.decodeIfPresent(Bool.self, forKey: .ad_use_checkpoint) ?? false
		self.ad_use_clip_skip = try container.decodeIfPresent(Bool.self, forKey: .ad_use_clip_skip) ?? false
		self.ad_use_inpaint_width_height = try container.decodeIfPresent(Bool.self, forKey: .ad_use_inpaint_width_height) ?? false
		self.ad_use_noise_multiplier = try container.decodeIfPresent(Bool.self, forKey: .ad_use_noise_multiplier) ?? false
		self.ad_use_sampler = try container.decodeIfPresent(Bool.self, forKey: .ad_use_sampler) ?? false
		self.ad_use_steps = try container.decodeIfPresent(Bool.self, forKey: .ad_use_steps) ?? false
		self.ad_use_vae = try container.decodeIfPresent(Bool.self, forKey: .ad_use_vae) ?? false
		self.ad_vae = try container.decodeIfPresent(String.self, forKey: .ad_vae) ?? "Use same VAE"
		self.ad_x_offset = try container.decodeIfPresent(Int.self, forKey: .ad_x_offset) ?? 0
		self.ad_y_offset = try container.decodeIfPresent(Int.self, forKey: .ad_y_offset) ?? 0
		self.is_api = try container.decodeIfPresent([Bool?].self, forKey: .is_api) ?? []
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

extension SDextensionADetailer {
	public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {

		var extractedDictionary: [String:Any?] = [:]
		let extractingKeyPairs_adetailer = [
			("ad_confidence", "adetailer confidence"),
			("ad_denoising_strength", "adetailer denoising strength"),
			("ad_dilate_erode", "adetailer dilate erode"),
			("ad_inpaint_only_masked", "adetailer inpaint only masked"),
			("ad_inpaint_only_masked_padding", "adetailer inpaint padding"),
			("ad_mask_blur", "adetailer mask blur"),
			("ad_mask_k_largest", "adetailer mask only top k largest"),
			("ad_model", "adetailer model"),
		]
		for (key, extractedKey) in extractingKeyPairs_adetailer {
			extractedDictionary[key] = jsonDictionary[extractedKey]
			jsonDictionary[extractedKey] = nil
		}

		fxdPrint(name: "extractedDictionary", dictionary: extractedDictionary)

		var decoded: Self? = nil
		if extractedDictionary.count > 0 {
			do {
				let adetailerData = try JSONSerialization.data(withJSONObject: extractedDictionary)
				decoded = try JSONDecoder().decode(Self.self, from: adetailerData)
				fxdPrint(decoded!)
			}
			catch {
				fxdPrint(error)
			}
		}

		return decoded
	}
}
