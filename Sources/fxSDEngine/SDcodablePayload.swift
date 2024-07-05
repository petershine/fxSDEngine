

import Foundation
import UIKit

import fXDKit


public struct SDcodablePayload: Codable {
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


	public init(from decoder: any Decoder) throws {
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
	mutating func evaluatedPayload(sdEngine: SDEngine) -> Data? {
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
		

		var alwayson_scripts: Dictionary<String, Any?> = [:]
		if sdEngine.isEnabledAdetailer,
		   sdEngine.use_adetailer {
			if sdEngine.extensionADetailer == nil {
				do {
					sdEngine.extensionADetailer = try JSONDecoder().decode(SDextensionADetailer.self, from: "{}".data(using: .utf8) ?? Data())
				}
				catch {	fxd_log()
					fxdPrint(error)
				}
			}
			alwayson_scripts[SDExtensionName.adetailer.rawValue] = sdEngine.extensionADetailer?.args
		}

		var extendedPayload: Data = payload

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
}
