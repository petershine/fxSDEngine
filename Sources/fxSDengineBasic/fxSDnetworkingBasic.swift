

import Foundation
import UIKit

import fXDKit


open class fxSDnetworkingBasic: NSObject, SDNetworking, @unchecked Sendable {
	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}

	fileprivate var responseHandler: ((Data?, URLResponse?, (any Error)?) -> Void)?
	fileprivate var receivedData: Data? = nil
}


extension fxSDnetworkingBasic: URLSessionDelegate, URLSessionDataDelegate {
	public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {	fxd_log()
		DispatchQueue.main.async {
			UIAlertController.errorAlert(error: error)
		}
	}

	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		if receivedData == nil {
			receivedData = Data()
		}
		receivedData?.append(data)
		fxdPrint(receivedData)
	}

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
		DispatchQueue.main.async {
			self.responseHandler?(self.receivedData, task.response, error)

			self.responseHandler = nil
			self.receivedData = nil
		}
	}
}
