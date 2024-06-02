

import Foundation
import UIKit

import fXDKit


public struct SDcodablePayload: Codable {
	var prompt: String? = nil
	var negative_prompt: String? = nil

	var sampler_name: String? = "DPM++ 2M SDE"
	var scheduler: String? = "Karras"
	var steps: Int? = 35
	var cfg_scale: Double? = 8.0

	var width: Int
	var height: Int

	var enable_hr: Bool = true
	var denoising_strength: Double? = 0.4
	var hr_scale: Double? = 1.5
	var hr_second_pass_steps: Int? = 10
	var hr_upscaler: String? = "4x-UltraSharp"
	var hr_scheduler: String? = "Karras"
	var hr_prompt: String? = nil
	var hr_negative_prompt: String? = nil

	var n_iter: Int? = 1	//batch count
	var batch_size: Int? = 1

	enum AlternativeCodingKeys: String, CodingKey {
		case sampler_name = "sampler"
		case scheduler = "schedule type"
		case cfg_scale = "cfg scale"

		case denoising_strength = "denoising strength"
		case hr_scale = "hires upscale"
		case hr_second_pass_steps = "hires steps"
		case hr_upscaler = "hires upscaler"
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
		self.negative_prompt = try container.decodeIfPresent(String.self, forKey: .negative_prompt)
		self.steps = try container.decodeIfPresent(Int.self, forKey: .steps)
		self.width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 512
		self.height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 768
		self.enable_hr = try container.decodeIfPresent(Bool.self, forKey: .enable_hr) ?? true
		self.hr_scheduler = try container.decodeIfPresent(String.self, forKey: .hr_scheduler)
		self.hr_prompt = try container.decodeIfPresent(String.self, forKey: .hr_prompt)
		self.hr_negative_prompt = try container.decodeIfPresent(String.self, forKey: .hr_negative_prompt)
		self.n_iter = try container.decodeIfPresent(Int.self, forKey: .n_iter)
		self.batch_size = try container.decodeIfPresent(Int.self, forKey: .batch_size)

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

	public func encodedPayload() -> Data? {
		var payload: Data? = nil
		do {
			payload = try JSONEncoder().encode(self)
		}
		catch {
			fxdPrint("\(error)")
		}
		guard payload != nil else {
			return nil
		}


		guard let scriptJSONfilename = Bundle.main.url(forResource: "encodableADetailer", withExtension: "json") else {
			return nil
		}

		do {
			let scriptData = try Data(contentsOf: scriptJSONfilename)
			let alwayson_scripts = try JSONSerialization.jsonObject(with: scriptData) as? Dictionary<String, Any>

			var payloadDictionary = try JSONSerialization.jsonObject(with: payload!) as? Dictionary<String, Any>

			if payloadDictionary != nil {
				payloadDictionary?["alwayson_scripts"] = alwayson_scripts
				payload = try JSONSerialization.data(withJSONObject: payloadDictionary!)
			}
		}
		catch {
			fxdPrint("\(error)")
		}

		return payload
	}
}


extension FXDmoduleSDEngine {
	func decodedGenerationPayload(decodedResponse: SDcodableGeneration) -> SDcodablePayload? {
		guard let infotext = decodedResponse.infotext() else {
			return nil
		}

		return decodedGenerationPayload(infotext: infotext)
	}

	func decodedGenerationPayload(receivedData: Data) -> SDcodablePayload? {
		guard let receivedString = String(data: receivedData, encoding: .utf8) else {
			return nil
		}

		return decodedGenerationPayload(infotext: receivedString)
	}


	func decodedGenerationPayload(infotext: String) -> SDcodablePayload? {	fxd_log()
		fxdPrint(infotext)
		guard !(infotext.isEmpty)
				&& (infotext.contains("Steps:"))
		else {
			return nil
		}


		let infoComponents = infotext.lineReBroken().components(separatedBy: "Steps:")
		let promptPair = infoComponents.first?.components(separatedBy: "Negative prompt:")

		let prompt = promptPair?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let negative_prompt = promptPair?.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

		guard !(prompt.isEmpty) else {
			fxdPrint(infotext)
			return nil
		}


		var payloadDictionary: [String:Any?] = [
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
					payloadDictionary[key] = doubleValue
				}
				else if let integerValue = Int(value) {
					payloadDictionary[key] = integerValue
				}
				else if let boolValue = Bool(value) {
					payloadDictionary[key] = boolValue
				}
				else {
					payloadDictionary[key] = value
				}
			}
		}


		fxdPrint(dictionary: payloadDictionary)

		var decodedPayload: SDcodablePayload? = nil
		do {
			let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
			decodedPayload = try JSONDecoder().decode(SDcodablePayload.self, from: payloadData)
			fxdPrint(decodedPayload!)
		}
		catch {
			fxdPrint(error)
		}

		return decodedPayload
	}
}
