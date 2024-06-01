

import Foundation
import UIKit

import fXDKit


public struct SDencodablePayload: Encodable {
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

	public init(prompt: String, negative_prompt: String) {
		self.prompt = prompt
		self.negative_prompt = negative_prompt

		self.hr_prompt = self.prompt
		self.hr_negative_prompt = self.negative_prompt
	}

	public func generationInfo() -> Data? {
		var generationInfo: Data? = nil
		do {
			generationInfo = try JSONEncoder().encode(self)
		}
		catch {
			fxdPrint("\(error)")
		}
		guard generationInfo != nil else {
			return nil
		}


		guard let encodableADetailer = Bundle.main.url(forResource: "encodableADetailer", withExtension: "json") else {
			return nil
		}

		do {
			let ADetailerData = try Data(contentsOf: encodableADetailer)
			let ADetailerDictionary = try JSONSerialization.jsonObject(with: ADetailerData) as? Dictionary<String, Any>

			var generationDictionary = try JSONSerialization.jsonObject(with: generationInfo!) as? Dictionary<String, Any>

			if generationDictionary != nil {
				generationDictionary?["alwayson_scripts"] = ADetailerDictionary
				generationInfo = try JSONSerialization.data(withJSONObject: generationDictionary!)
			}
		}
		catch {
			fxdPrint("\(error)")
		}

		return generationInfo
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
		catch let decodeException {
			fxdPrint("decodeException: \(String(describing: decodeException))")

			let _ = decodedJSONobject(receivedData: receivedData)
		}

		return decodedResponse
	}

	func decodedJSONobject(receivedData: Data, quiet: Bool = false) -> Dictionary<String, Any?>? {
		var jsonObject: Dictionary<String, Any?>? = nil
		do {
			jsonObject = try JSONSerialization.jsonObject(with: receivedData, options: .mutableContainers) as? Dictionary<String, Any?>
			fxdPrint("jsonObject: \(String(describing: jsonObject))", quiet:quiet)
		}
		catch let jsonError {
			let receivedString = String(data: receivedData, encoding: .utf8)
			fxdPrint("receivedString: \(String(describing: receivedString))")
			fxdPrint("jsonError: \(jsonError)")
		}

		return jsonObject
	}

	func encodeGenerationPayload(receivedData: Data) -> SDencodablePayload? {
		guard let receivedString = String(data: receivedData, encoding: .utf8) else {
			fxdPrint("receivedString: \(String(describing: String(data: receivedData, encoding: .utf8)))")
			return nil
		}

		return encodeGenerationPayload(infotext: receivedString)
	}


	func encodeGenerationPayload(infotext: String) -> SDencodablePayload? {
		guard !(infotext.isEmpty)
				&& (infotext.contains("Negative prompt:"))
		else {
			fxdPrint("infotext: \(String(describing: infotext))")
			return nil
		}


		var separators = [
			("Negative prompt:", false, false),
			("Steps:", false, true)
		]

		if infotext.contains("Wildcard prompt:") {
			separators.append(("Wildcard prompt:", false, true))
		}

		if infotext.contains("Hires upscale:") {
			separators.append(("Hires upscale:", true, true))
		}
		fxdPrint("separators: \(separators)")

		var modifiedString: String = infotext
		var parsed: [String] = []
		for (separator, shouldPickLast, shouldPrefix) in separators {
			let components = modifiedString.components(separatedBy: separator)
			let extracted = (shouldPickLast ? components.last : components.first)?.trimmingCharacters(in: .whitespacesAndNewlines)
			let processed = extracted?.replacingOccurrences(of: "\\n", with: "\n")
			parsed.append(processed ?? "")

			modifiedString = "\(shouldPrefix ? (separator+" ") : "")\(components.last ?? "")"
		}

		guard !(parsed[0].isEmpty) else {
			fxdPrint("infotext: \(String(describing: infotext))")
			return nil
		}

		var modifiedPrompt = parsed[0]
		if modifiedPrompt.first == "\"" {
			modifiedPrompt.removeFirst()
			parsed[0] = modifiedPrompt
		}

		#if DEBUG
		fxdPrint("parsed[0]:\n\(parsed[0])\n\n")
		fxdPrint("parsed[1]:\n\(parsed[1])\n\n")
		#endif

		let encodablePayload = SDencodablePayload(
			prompt: parsed[0],
			negative_prompt: parsed[1]
		)


		return encodablePayload
	}
}

extension FXDmoduleSDEngine {
	func decodedImages(imagesEncoded: [String?], quiet: Bool = false) -> [UIImage] {
		fxdPrint("[STARTED DECODING]: \(String(describing: imagesEncoded.count)) image(s)", quiet:quiet)

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

		let keys = [
			"info",
			"infotexts",
		]

		var extracted: Any? = nil
		var caughError: Bool = false
		for key in keys {
			extracted = jsonObject?[key]
			jsonObject?[key] = "[EXTRACTED]"

			fxdPrint("[without extracted: \(key)]:\n\(jsonObject)\n")

			guard let extractedDictionary = extracted as? [String:Any?] else {
				break
			}

			jsonObject = extractedDictionary
		}

		fxdPrint("[\(keys.last)]:\n\(extracted)\n")
	}
}
#endif
