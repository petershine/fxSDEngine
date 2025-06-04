import Foundation
import UIKit

public struct SDcodableGenerated: Codable {
    public var images: [String?]?
    var info: String?
}

extension SDcodableGenerated {
    var infotext: String? {
        guard let info,
              let infoData = info.data(using: .utf8)
        else {
            return nil
        }

        do {
            let infoDictionary = try JSONSerialization.jsonObject(with: infoData) as? [String: Any?]

            let infotext = (infoDictionary?["infotexts"] as? [Any])?.first
            return infotext as? String
        } catch {
        }

        return nil
    }
}

extension SDcodableGenerated {
	public func decodedImages(quiet: Bool = false) -> [UIImage] {
		var decodedImageArray: [UIImage] = []
		for base64string in (images ?? []) {
			guard base64string != nil, !(base64string!.isEmpty) else {
				continue
			}

			guard let decodedImage = base64string?.decodedImage() else {
				continue
			}

			decodedImageArray.append(decodedImage)
		}

		return decodedImageArray
	}
}
