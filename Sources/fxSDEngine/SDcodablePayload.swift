

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

	var override_settings: SDcodableOverride?
	var override_settings_restore_afterwards: Bool = true


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


		var parametersDictionary: [String:Any?] = [
			"prompt" : prompt,
			"negative_prompt" : negative_prompt
		]

		let parametersString = "Steps: \(infoComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"
		let parameters = parametersString.components(separatedBy: ",")
		for parameter in parameters {
			let key_value = parameter.components(separatedBy: ":")

			let key: String = key_value.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
			if !key.isEmpty {
				let value: String = key_value.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
				if let doubleValue = Double(value) {
					parametersDictionary[key] = doubleValue
				}
				else if let integerValue = Int(value) {
					parametersDictionary[key] = integerValue
				}
				else if let boolValue = Bool(value) {
					parametersDictionary[key] = boolValue
				}
				else {
					parametersDictionary[key] = value
				}
			}
		}

		if let sizeComponents = (parametersDictionary["size"] as? String)?.components(separatedBy: "x"),
		   sizeComponents.count == 2 {
			parametersDictionary["width"] = Int(sizeComponents.first ?? "504")
			parametersDictionary["height"] = Int(sizeComponents.last ?? "768")
		}

		parametersDictionary["sampler_name"] = parametersDictionary["sampler"]
		parametersDictionary["scheduler"] = parametersDictionary["schedule type"]
		parametersDictionary["cfg_scale"] = parametersDictionary["cfg scale"]
		
		parametersDictionary["denoising_strength"] = parametersDictionary["denoising strength"]
		parametersDictionary["hr_scale"] = parametersDictionary["hires upscale"]
		parametersDictionary["hr_second_pass_steps"] = parametersDictionary["hires steps"]
		parametersDictionary["hr_upscaler"] = parametersDictionary["hires upscaler"]

		
		fxd_log()
		fxdPrint("[infotext]", infotext)
		fxdPrint(name: "parametersDictionary", dictionary: parametersDictionary)

		var decodedPayload: Self? = nil
		do {
			let payloadData = try JSONSerialization.data(withJSONObject: parametersDictionary)
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
