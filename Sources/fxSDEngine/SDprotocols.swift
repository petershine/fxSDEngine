
import OSLog
import Foundation
import UIKit

import fXDKit


public protocol SDcodableResponse: Codable {
	static func decoded(_ receivedData: Data) -> (any SDcodableResponse)?
}

extension SDcodableResponse {
	public static func decoded(_ receivedData: Data) -> (any SDcodableResponse)? {
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
