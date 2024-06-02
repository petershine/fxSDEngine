

import Foundation
import UIKit

import fXDKit


public struct SDcodablePayload: Codable {
	var prompt: String? = nil
	var negative_prompt: String? = nil

	var sampler_name: String = "DPM++ 2M SDE"
	var scheduler: String = "Karras"
	var steps: Int = 30
	var cfg_scale: Double = 7.0

	var width: Int = 512
	var height: Int = 768

	var enable_hr: Bool = true
	var denoising_strength: Double = 0.4
	var hr_scale: Double = 1.5
	var hr_second_pass_steps: Int = 10
	var hr_upscaler: String = "4x-UltraSharp"
	var hr_scheduler: String = "Karras"
	var hr_prompt: String? = nil
	var hr_negative_prompt: String? = nil

	var n_iter: Int = 1	//batch count
	var batch_size: Int = 1


	public func payload() -> Data? {
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

public struct SDcodableResponse: Codable {
	// txt2img
	var images: [String?]? = nil

	// progress
	var progress: Double? = nil
	var eta_relative: Date? = nil
	var textinfo: String? = nil
	var current_image: String? = nil
	public var state: SDcodableState? = nil
	public struct SDcodableState: Codable {
		var interrupted: Bool? = nil
		var job: String? = nil
		var job_count: Int? = nil
		var job_no: Int? = nil
		var job_timestamp: String? = nil
		var sampling_step: Int? = nil
		var sampling_steps: Int? = nil
		var skipped: Bool? = nil
		var stopping_generation: Bool? = nil

		public func isJobRunning() -> Bool {
			return !((job ?? "").isEmpty || interrupted ?? true)
		}
	}

	// sysinfo
	var Config: SDcodableConfig? = nil
	struct SDcodableConfig: Codable {
		var outdir_samples: String? = nil
	}


	// file
	var files: [SDcodableFile?]? = nil
	struct SDcodableFile: Codable {
		var type: String? = nil
		var size: String? = nil
		var name: String? = nil
		var fullpath: String? = nil
		var is_under_scanned_path: Bool? = nil
		var date: String? = nil
		var created_time: String? = nil

		func updated_time() -> Date? {
			guard date != nil else {
				return nil
			}

			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
			return dateFormatter.date(from:date!)
		}
	}
}


extension FXDmoduleSDEngine {
	func decodedResponse(receivedData: Data) -> SDcodableResponse? {
		var decodedResponse: SDcodableResponse? = nil
		do {
			decodedResponse = try JSONDecoder().decode(SDcodableResponse.self, from: receivedData)
		}
		catch {
			fxdPrint(error)
			let _ = decodedJSONobject(receivedData: receivedData)
		}

		return decodedResponse
	}

	func decodedJSONobject(receivedData: Data, quiet: Bool = false) -> Dictionary<String, Any?>? {
		var jsonObject: Dictionary<String, Any?>? = nil
		do {
			jsonObject = try JSONSerialization.jsonObject(with: receivedData, options: .mutableContainers) as? Dictionary<String, Any?>
			fxdPrint(jsonObject, quiet:quiet)
		}
		catch {
			fxdPrint(error)
			let receivedString = String(data: receivedData, encoding: .utf8)
			fxdPrint(receivedString)
		}

		return jsonObject
	}

	func encodeGenerationPayload(receivedData: Data) -> SDcodablePayload? {
		guard let receivedString = String(data: receivedData, encoding: .utf8) else {
			return nil
		}

		return encodeGenerationPayload(infotext: receivedString)
	}


	func encodeGenerationPayload(infotext: String) -> SDcodablePayload? {	fxd_log()
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
				payloadDictionary[key] = value
			}
		}


		fxdPrint(dictionary: payloadDictionary)

		var encodablePayload: SDcodablePayload? = nil
		do {
			let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
			encodablePayload = try JSONDecoder().decode(SDcodablePayload.self, from: payloadData)
			fxdPrint(encodablePayload)
		}
		catch {
			fxdPrint(error)
		}

		return encodablePayload
	}
}

extension FXDmoduleSDEngine {
	func decodedImages(imagesEncoded: [String?], quiet: Bool = false) -> [UIImage] {
		fxdPrint("[STARTED DECODING]: \(imagesEncoded.count) image(s)", quiet:quiet)

		var decodedImageArray: [UIImage] = []
		for base64string in imagesEncoded {
			guard base64string != nil, !(base64string!.isEmpty) else {
				continue
			}


			guard let imageData = Data(base64Encoded: base64string!) else {
				continue
			}
			fxdPrint("imageData byte count: \(imageData.count)", quiet:quiet)

			guard let decodedImage = UIImage(data: imageData) else {
				continue
			}
			fxdPrint("decodedImage: \(decodedImage)", quiet:quiet)

			decodedImageArray.append(decodedImage)
		}

		return decodedImageArray
	}
}


#if DEBUG
extension FXDmoduleSDEngine {
	func fxdebug(data: Data) {
		var jsonObject = self.decodedJSONobject(receivedData: data, quiet: true)
		jsonObject?["images"] = ["<IMAGE base64 string>"]

		//fxdPrint("[TXT2IMG] jsonObject:\n\(jsonObject)\n")
		for (key, value) in jsonObject?.enumerated() ?? [:].enumerated() {
			fxdPrint("[TXT2IMG] \(key):\n\(value)\n")
		}

		let infoDictionary = jsonObject?["info"]
		fxdPrint("[TXT2IMG] info:\n\(infoDictionary)\n")

		let infotexts = (infoDictionary as? [String:Any?])?["infotexts"]
		fxdPrint("[TXT2IMG] infotexts:\n\(infotexts)\n")

		let encodedPayload = encodeGenerationPayload(infotext: infotexts as? String ?? "")
		fxdPrint("[TXT2IMG] encodedPayload:\n\(encodedPayload)")
	}
}
#endif
