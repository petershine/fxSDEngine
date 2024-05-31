

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
}

public struct SDcodableResponse: Codable {
	var progress: Double? = nil
	var eta_relative: Double? = nil

	var textinfo: String? = nil

	var current_image: String? = nil
	var images: [String?]? = nil


	var Config: SDcodableConfig? = nil
	struct SDcodableConfig: Codable {
		var outdir_samples: String? = nil
	}


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
		var receivedString = String(data: receivedData, encoding: .utf8)
		receivedString = receivedString?.replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
		fxdPrint("receivedString?.count: \(String(describing: receivedString?.count))")

		guard !(receivedString?.isEmpty ?? true)
				&& (receivedString?.contains("Negative prompt:") ?? false)
		else {
			fxdPrint("receivedString: \(String(describing: receivedString))")
			return nil
		}


		var separators = [
			("Negative prompt:", false, false),
			("Steps:", false, true)
		]

		if receivedString?.contains("Wildcard prompt:") ?? false {
			separators.append(("Wildcard prompt:", false, true))
		}

		if receivedString?.contains("Hires upscale:") ?? false {
			separators.append(("Hires upscale:", true, true))
		}
		fxdPrint("separators: \(separators)")

		var modifiedString: String = receivedString ?? ""
		var parsed: [String] = []
		for (separator, shouldPickLast, shouldPrefix) in separators {
			let components = modifiedString.components(separatedBy: separator)
			let picked = (shouldPickLast ? components.last : components.first)?.trimmingCharacters(in: .whitespacesAndNewlines)
			parsed.append(picked ?? "")

			modifiedString = "\(shouldPrefix ? (separator+" ") : "")\(components.last ?? "")"
		}


		let encodablePayload = SDencodablePayload(
			prompt: parsed[0],
			negative_prompt: parsed[1]
		)

		guard !(parsed[0].isEmpty) else {
			fxdPrint("receivedString: \(String(describing: receivedString))")
			return nil
		}

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

