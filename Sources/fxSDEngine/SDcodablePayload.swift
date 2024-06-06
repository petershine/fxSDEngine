

import Foundation
import UIKit

import fXDKit


public class SDcodablePayload: Codable {
	public var prompt: String
	public var negative_prompt: String

	var sampler_name: String?
	var scheduler: String?
	var steps: Int
	var cfg_scale: Double?

	var width: Int
	var height: Int

	var enable_hr: Bool
	var denoising_strength: Double?
	var hr_scale: Double?
	var hr_second_pass_steps: Int?
	var hr_upscaler: String?
	var hr_scheduler: String
	var hr_prompt: String
	var hr_negative_prompt: String

	var n_iter: Int
	var batch_size: Int

	var save_images: Bool

	enum AlternativeCodingKeys: String, CodingKey {
		case sampler_name = "sampler"
		case scheduler = "schedule type"
		case cfg_scale = "cfg scale"

		case denoising_strength = "denoising strength"
		case hr_scale = "hires upscale"
		case hr_second_pass_steps = "hires steps"
		case hr_upscaler = "hires upscaler"
	}


	required public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? "fxSDEngine!"
		self.negative_prompt = try container.decodeIfPresent(String.self, forKey: .negative_prompt) ?? ""

		self.steps = try container.decodeIfPresent(Int.self, forKey: .steps) ?? 35

		self.width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 512
		self.height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 768

		self.enable_hr = try container.decodeIfPresent(Bool.self, forKey: .enable_hr) ?? false
		self.hr_scheduler = try container.decodeIfPresent(String.self, forKey: .hr_scheduler) ?? "Karras"
		self.hr_prompt = try container.decodeIfPresent(String.self, forKey: .hr_prompt) ?? self.prompt
		self.hr_negative_prompt = try container.decodeIfPresent(String.self, forKey: .hr_negative_prompt) ?? self.negative_prompt

		self.n_iter = try container.decodeIfPresent(Int.self, forKey: .n_iter) ?? 1
		self.batch_size = try container.decodeIfPresent(Int.self, forKey: .batch_size) ?? 1

		self.save_images = try container.decodeIfPresent(Bool.self, forKey: .save_images) ?? true


		self.sampler_name = "DPM++ 2M SDE"
		self.scheduler = "Karras"
		self.cfg_scale = 8.0

		self.denoising_strength = 0.4
		self.hr_scale = 1.5
		self.hr_second_pass_steps = 10
		self.hr_upscaler = "4x-UltraSharp"


		self.sampler_name = try container.decodeIfPresent(String.self, forKey: .sampler_name)
		self.scheduler = try container.decodeIfPresent(String.self, forKey: .scheduler)
		self.cfg_scale = try container.decodeIfPresent(Double.self, forKey: .cfg_scale)

		self.denoising_strength = try container.decodeIfPresent(Double.self, forKey: .denoising_strength)
		self.hr_scale = try container.decodeIfPresent(Double.self, forKey: .hr_scale)
		self.hr_second_pass_steps = try container.decodeIfPresent(Int.self, forKey: .hr_second_pass_steps)
		self.hr_upscaler = try container.decodeIfPresent(String.self, forKey: .hr_upscaler)


		if self.cfg_scale == nil
			|| self.sampler_name == nil {
			let alternativeContainer = try decoder.container(keyedBy: AlternativeCodingKeys.self)

			self.sampler_name = try alternativeContainer.decodeIfPresent(String.self, forKey: .sampler_name)
			self.scheduler = try alternativeContainer.decodeIfPresent(String.self, forKey: .scheduler)
			self.cfg_scale = try alternativeContainer.decodeIfPresent(Double.self, forKey: .cfg_scale)

			self.denoising_strength = try alternativeContainer.decodeIfPresent(Double.self, forKey: .denoising_strength)
			self.hr_scale = try alternativeContainer.decodeIfPresent(Double.self, forKey: .hr_scale)
			self.hr_second_pass_steps = try alternativeContainer.decodeIfPresent(Int.self, forKey: .hr_second_pass_steps)
			self.hr_upscaler = try alternativeContainer.decodeIfPresent(String.self, forKey: .hr_upscaler)
		}
	}
}

extension SDcodablePayload {
	func encodedPayload() -> Data? {
		var payload: Data? = nil
		do {
			payload = try JSONEncoder().encode(self)
		}
		catch {	fxd_log()
			fxdPrint("error:", error)
		}

		return payload
	}
}

extension SDcodablePayload {
	func evaluatedPayload(extensions: [SDcodableExtension?]?) -> Data? {
		guard let payload: Data = encodedPayload() else {
			return nil
		}

		guard let filtered = extensions?.filter({ $0?.name?.lowercased() == "adetailer"}),
			  filtered.count > 0
		else {
			return payload
		}

		guard let scriptJSONfilename = Bundle.main.url(forResource: "encodableADetailer", withExtension: "json") else {
			return payload
		}


		var extendedPayload: Data? = nil
		do {
			let scriptData = try Data(contentsOf: scriptJSONfilename)
			let alwayson_scripts = try JSONSerialization.jsonObject(with: scriptData) as? Dictionary<String, Any>

			var payloadDictionary = try JSONSerialization.jsonObject(with: payload) as? Dictionary<String, Any>

			if payloadDictionary != nil {
				payloadDictionary?["alwayson_scripts"] = alwayson_scripts
				extendedPayload = try JSONSerialization.data(withJSONObject: payloadDictionary!)
			}
		}
		catch {	fxd_log()
			fxdPrint("error:", error)
		}

		return extendedPayload ?? payload
	}
}

extension SDcodablePayload {
	static func decoded(infotext: String) -> SDcodablePayload? {	fxd_log()
		fxdPrint("[infotext]", infotext)
		guard !(infotext.isEmpty)
				&& (infotext.contains("Steps:"))
		else {
			return nil
		}


		let infoComponents = infotext.lineReBroken().components(separatedBy: "Steps:")
		let promptPair = infoComponents.first?.components(separatedBy: "Negative prompt:")

		var prompt = promptPair?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if prompt.first == "\"" {
			prompt.removeFirst()
		}

		let negative_prompt = promptPair?.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

		guard !(prompt.isEmpty) else {
			return nil
		}


		var parametersDictionary: [String:Any] = [
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

		let hr_scale = (parametersDictionary["hr_scale"] ?? parametersDictionary["hires upscale"]) as? Double ?? 1.0
		if hr_scale > 1.0,
		   parametersDictionary["enable_hr"] == nil {
			parametersDictionary["enable_hr"] = true
		}

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
	public func modified(editedPrompt: String, editedNegativePrompt: String) -> SDcodablePayload? {
		let didChangePrompt = !(self.prompt == editedPrompt)
		let didChangeNegativePrompt = !(self.negative_prompt == editedNegativePrompt)

		guard (didChangePrompt || didChangeNegativePrompt) else {
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
