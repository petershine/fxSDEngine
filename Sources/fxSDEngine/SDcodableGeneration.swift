

import Foundation
import UIKit

import fXDKit


struct SDcodableGeneration: SDcodableResponse {
	public var images: [String?]? = nil
	var info: String? = nil

	public func infotext() -> String? {
		guard let info = self.info,
			  let infoData = info.data(using: .utf8)
		else {
			return nil
		}


		do {
			let infoDictionary = try JSONSerialization.jsonObject(with: infoData) as? Dictionary<String, Any?>

			if let infotext = (infoDictionary?["infotexts"] as? Array<Any>)?.first {
				return infotext as? String
			}
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return nil
	}
}


extension SDcodableGeneration {
	func decodedImages(quiet: Bool = false) -> [UIImage] {
		fxdPrint("[STARTED DECODING]: \(images?.count ?? 0) image(s)", quiet:quiet)

		var decodedImageArray: [UIImage] = []
		for base64string in (images ?? []) {
			guard base64string != nil, !(base64string!.isEmpty) else {
				continue
			}

			guard let decodedImage = base64string?.decodedImage() else {
				continue
			}

			fxdPrint("decodedImage: \(decodedImage)", quiet:quiet)
			decodedImageArray.append(decodedImage)
		}

		return decodedImageArray
	}
}


extension String {
	func decodedImage() -> UIImage? {
		guard let imageData = Data(base64Encoded: self) else {
			return nil
		}

		guard let decoded = UIImage(data: imageData) else {
			return nil
		}

		return decoded
	}
}

