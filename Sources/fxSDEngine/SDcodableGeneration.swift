

import Foundation

import fXDKit


struct SDcodableGeneration: SDcodableResponse {
	var images: [String?]? = nil
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
