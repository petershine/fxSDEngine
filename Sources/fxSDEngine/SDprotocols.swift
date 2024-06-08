
import OSLog
import Foundation
import UIKit

import fXDKit


protocol SDcodableResponse: Codable {
	static func decoded(_ receivedData: Data) -> (any SDcodableResponse)?
}

extension SDcodableResponse {
	static func decoded(_ receivedData: Data) -> (any SDcodableResponse)? {
		var decodedResponse: (any SDcodableResponse)? = nil
		do {
			decodedResponse = try JSONDecoder().decode(Self.self, from: receivedData)
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return decodedResponse
	}
}
