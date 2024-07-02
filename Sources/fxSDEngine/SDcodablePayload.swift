

import Foundation
import UIKit

import fXDKit


public class SDcodablePayload: Codable {
	public var prompt: String
	public var negative_prompt: String

	public var steps: Int
	public var cfg_scale: Double
	var sampler_name: String
	var scheduler: String

	public var width: Int
	public var height: Int

	public var hr_scale: Double
	public var enable_hr: Bool
	var denoising_strength: Double
	var hr_second_pass_steps: Int
	var hr_upscaler: String
	var hr_scheduler: String
	var hr_prompt: String
	var hr_negative_prompt: String

	public var n_iter: Int
	var batch_size: Int

	var save_images: Bool
	var send_images: Bool

	public var seed: Int

	var do_not_save_samples: Bool
	var do_not_save_grid: Bool

	var override_settings_restore_afterwards: Bool = true
	var override_settings: SDcodableOverride?
	struct SDcodableOverride: Codable {
		var sd_model_checkpoint: String?
	}


	required public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
		self.negative_prompt = try container.decodeIfPresent(String.self, forKey: .negative_prompt) ?? ""

		self.steps = try container.decodeIfPresent(Int.self, forKey: .steps) ?? 30
		self.cfg_scale = try container.decodeIfPresent(Double.self, forKey: .cfg_scale) ?? 7.0
		self.sampler_name = try container.decodeIfPresent(String.self, forKey: .sampler_name) ?? "DPM++ 2M SDE"
		self.scheduler = try container.decodeIfPresent(String.self, forKey: .scheduler) ?? "Karras"


		self.height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 768
		var aspectRatio = UIScreen.main.nativeBounds.size.width/UIScreen.main.nativeBounds.size.height
		if UIDevice.current.userInterfaceIdiom == .phone {
			aspectRatio = max(504.0/768.0, aspectRatio)
		}
		self.width = try container.decodeIfPresent(Int.self, forKey: .width) ?? Int(CGFloat(self.height) * aspectRatio)

		self.hr_scale = try container.decodeIfPresent(Double.self, forKey: .hr_scale) ?? 1.0

		var shouldEnable_hr = false
		if self.hr_scale > 1.0 {
			shouldEnable_hr = true
		}
		self.enable_hr = try container.decodeIfPresent(Bool.self, forKey: .enable_hr) ?? shouldEnable_hr

		self.denoising_strength = try container.decodeIfPresent(Double.self, forKey: .denoising_strength) ?? 0.3
		self.hr_second_pass_steps = try container.decodeIfPresent(Int.self, forKey: .hr_second_pass_steps) ?? 10
		self.hr_upscaler = try container.decodeIfPresent(String.self, forKey: .hr_upscaler) ?? "4x-UltraSharp"
		self.hr_scheduler = try container.decodeIfPresent(String.self, forKey: .hr_scheduler) ?? "Karras"
		self.hr_prompt = try container.decodeIfPresent(String.self, forKey: .hr_prompt) ?? ""
		self.hr_negative_prompt = try container.decodeIfPresent(String.self, forKey: .hr_negative_prompt) ?? ""

		self.n_iter = try container.decodeIfPresent(Int.self, forKey: .n_iter) ?? 1
		self.batch_size = try container.decodeIfPresent(Int.self, forKey: .batch_size) ?? 1

		self.save_images = try container.decodeIfPresent(Bool.self, forKey: .save_images) ?? true
		self.send_images = try container.decodeIfPresent(Bool.self, forKey: .send_images) ?? true

		self.seed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? -1

		self.do_not_save_samples = try container.decodeIfPresent(Bool.self, forKey: .do_not_save_samples) ?? false
		self.do_not_save_grid = try container.decodeIfPresent(Bool.self, forKey: .do_not_save_grid) ?? false
	}
}

extension SDcodablePayload {
	public func encodedPayload() -> Data? {
		var payload: Data? = nil
		do {
			payload = try JSONEncoder().encode(self)
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return payload
	}
}


extension SDcodablePayload {
	func evaluatedPayload(sdEngine: SDmoduleMain) -> Data? {
		self.seed = sdEngine.use_lastSeed ? self.seed : -1

		guard let payload: Data = encodedPayload() else {
			return nil
		}


		var payloadDictionary: Dictionary<String, Any?>? = nil
		do {
			payloadDictionary = try JSONSerialization.jsonObject(with: payload) as? Dictionary<String, Any?>
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		guard payloadDictionary != nil else {
			return nil
		}
		

		var extensionNames: Set<SDExtensionName> = []
		if sdEngine.use_adetailer {
			extensionNames.insert(.adetailer)
		}

		var extendedPayload: Data = payload

		let alwayson_scripts = sdEngine.systemInfo?.alwayson_scripts(extensionNames: extensionNames) ?? [:]
		if alwayson_scripts.count > 0 {
			payloadDictionary?["alwayson_scripts"] = alwayson_scripts

			do {
				extendedPayload = try JSONSerialization.data(withJSONObject: payloadDictionary!)
			}
			catch {	fxd_log()
				fxdPrint(error)
			}
		}

		return extendedPayload
	}
}

extension SDcodablePayload {
	public static func minimalPayload() -> Self? {
		let minimalJSON =
"""
{
"prompt" : "(the most beautiful photo), deep forest",
"negative_prompt" : "(random painting)"
}
"""

		var minimalPayload: Self? = nil
		do {
			minimalPayload = try JSONDecoder().decode(Self.self, from: minimalJSON.data(using: .utf8) ?? Data())
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return minimalPayload
	}

	public static func decoded(infotext: String) -> Self? {
		guard !(infotext.isEmpty)
				&& (infotext.contains("Steps:"))
		else {	fxd_log()
			fxdPrint("[infotext]", infotext)
			return nil
		}


		let infoComponents = infotext.lineReBroken().components(separatedBy: "Steps:")
		let promptPair = infoComponents.first?.components(separatedBy: "Negative prompt:")

		var prompt = promptPair?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if prompt.first == "\"" {
			prompt.removeFirst()
		}

		let negative_prompt = promptPair?.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

		guard !(prompt.isEmpty) else {	fxd_log()
			fxdPrint("[infotext]", infotext)
			return nil
		}


		let parametersString = "Steps: \(infoComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"

		var payloadDictionary: [String:Any?] = parametersString.jsonDictionary() ?? [:]
		payloadDictionary["prompt"] = prompt
		payloadDictionary["negative_prompt"] = negative_prompt

		if let sizeComponents = (payloadDictionary["size"] as? String)?.components(separatedBy: "x"),
		   sizeComponents.count == 2 {
			payloadDictionary["width"] = Int(sizeComponents.first ?? "504")
			payloadDictionary["height"] = Int(sizeComponents.last ?? "768")
		}

		let replacingKeyPairs = [
			("sampler_name", "sampler"),
			("scheduler", "schedule type"),
			("cfg_scale", "cfg scale"),

			("denoising_strength", "denoising strength"),
			("hr_scale", "hires upscale"),
			("hr_second_pass_steps", "hires steps"),
			("hr_upscaler", "hires upscaler"),
		]

		for (key, replacedKey) in replacingKeyPairs {
			payloadDictionary[key] = payloadDictionary[replacedKey]
			payloadDictionary[replacedKey] = nil
		}


		var adetailerDictionary: [String:Any?] = [:]
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
			adetailerDictionary[key] = payloadDictionary[extractedKey]
			payloadDictionary[extractedKey] = nil
		}

		
		fxd_log()
		fxdPrint("[infotext]", infotext)
		fxdPrint(name: "payloadDictionary", dictionary: payloadDictionary)
		fxdPrint(name: "adetailerDictionary", dictionary: adetailerDictionary)

		var decodedPayload: Self? = nil
		do {
			let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
			decodedPayload = try JSONDecoder().decode(Self.self, from: payloadData)
			fxdPrint(decodedPayload!)
		}
		catch {
			fxdPrint(error)
		}

		return decodedPayload
	}
}

extension SDcodablePayload {
	public func modified(editedPrompt: String, editedNegativePrompt: String) -> Self? {
		let didChangePrompt = !(self.prompt == editedPrompt)
		let didChangeNegativePrompt = !(self.negative_prompt == editedNegativePrompt)

		guard (didChangePrompt
			   || didChangeNegativePrompt)
		else {
			return nil
		}


		if didChangePrompt {
			self.prompt = editedPrompt
		}

		if didChangeNegativePrompt {
			self.negative_prompt = editedNegativePrompt
		}

		return self
	}
}
