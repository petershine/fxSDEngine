

import Foundation
import UIKit

import fXDKit


open class fxSDnetworkingBasic: NSObject, SDNetworking, @unchecked Sendable {
	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}

	public func requestToSDServer(
		quiet: Bool = false,
		api_endpoint: SDAPIendpoint,
		method: String? = nil,
		query: String? = nil,
		payload: Data? = nil,
		responseHandler: ((_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void)?) {
			if !quiet {
				fxd_log()
			}

			var requestPath = "\(SD_SERVER_HOSTNAME)/\(api_endpoint.rawValue)"
			if !(query?.isEmpty ?? true),
			   let escapedQuery = query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
				requestPath += "?\(escapedQuery)"
			}

			fxdPrint("requestPath: ", requestPath, quiet:quiet)

			guard let requestURL = URL(string: requestPath) else {
				responseHandler?(nil, nil, nil)
				return
			}


			var httpRequest = URLRequest(url: requestURL)
			httpRequest.timeoutInterval = .infinity
			httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

			httpRequest.httpMethod = method ?? "GET"
			if payload != nil {
				fxdPrint(name: "PAYLOAD", dictionary: payload?.jsonDictionary())
				httpRequest.httpMethod = "POST"
				httpRequest.httpBody = payload
			}


			let completionHandler = {
				(data: Data?, response: URLResponse?, error: Error?) in

				let statusCode = (response as? HTTPURLResponse)?.statusCode
				fxdPrint("response.statusCode: ", statusCode, quiet:quiet)
				fxdPrint("data: ", data, quiet:quiet)
				fxdPrint("error: ", error, quiet:quiet)

				if data == nil || statusCode != 200 {
					fxdPrint("httpURLResponse: ", (response as? HTTPURLResponse), quiet:quiet)

					fxdPrint("httpRequest.url: ", httpRequest.url)
					fxdPrint("httpRequest.allHTTPHeaderFields: ", httpRequest.allHTTPHeaderFields)
					fxdPrint("httpRequest.httpMethod: ", httpRequest.httpMethod)
					fxdPrint("httpRequest.httpBody: ", httpRequest.httpBody)
				}

				let processedError = SDError.processsed(data, response, error)
				responseHandler?(data, response, processedError)
			}


			let httpTask = URLSession.shared.dataTask(with: httpRequest, completionHandler: completionHandler)
			httpTask.resume()
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
