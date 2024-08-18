

import Foundation
import UIKit


public struct SDcodableGenerated: Codable {
    public var images: [String?]? = nil
    var info: String? = nil
}

extension SDcodableGenerated {
    var infotext: String? {
        guard let info,
              let infoData = info.data(using: .utf8)
        else {
            return nil
        }


        do {
            let infoDictionary = try JSONSerialization.jsonObject(with: infoData) as? Dictionary<String, Any?>

            let infotext = (infoDictionary?["infotexts"] as? Array<Any>)?.first
            return infotext as? String
        }
        catch {
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
