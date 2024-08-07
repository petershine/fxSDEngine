

import Foundation
import UIKit

import fXDKit


public struct SDcodableGenerated: Codable {
	public var images: [String?]? = nil
	var info: String? = nil

    var infotext: String? {
        guard let info,
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
        catch {    fxd_log()
            fxdPrint(error)
        }

        return nil
    }
}

extension SDcodableGenerated {
	public func decodedImages(quiet: Bool = false) -> [UIImage] {	fxd_log()
		fxdPrint("[STARTED DECODING]: ", images?.count, " image(s)", quiet:quiet)

		var decodedImageArray: [UIImage] = []
		for base64string in (images ?? []) {
			guard base64string != nil, !(base64string!.isEmpty) else {
				continue
			}

			guard let decodedImage = base64string?.decodedImage() else {
				continue
			}

			fxdPrint("decodedImage: ", decodedImage, quiet:quiet)
			decodedImageArray.append(decodedImage)
		}

		return decodedImageArray
	}
}
