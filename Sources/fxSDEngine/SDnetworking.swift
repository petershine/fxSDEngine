
import Foundation
import UIKit

import fXDKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"

	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
	case SDAPI_V1_INTERRUPT = "sdapi/v1/interrupt"

	case INFINITE_IMAGE_BROWSING_FILES = "infinite_image_browsing/files"
	case INFINITE_IMAGE_BROWSING_FILE = "infinite_image_browsing/file"
	case INFINITE_IMAGE_BROWSING_GENINFO = "infinite_image_browsing/image_geninfo"
}

enum SDError: Error {
	case reason(msg: String?)
}

extension SDError: LocalizedError {
	var errorDescription: String? {
		switch self {
			case .reason(let msg):
				return NSLocalizedString("\(msg ?? "(Unknown reason)")", comment: "")
		}
	}
}


public protocol SDNetworking: NSObjectProtocol {
	var SD_SERVER_HOSTNAME: String { get }

	var backgroundSession: URLSession { get }
	var backgroundOperationQueue: OperationQueue { get }

	func requestToSDServer(
		quiet: Bool,
		api_endpoint: SDAPIendpoint,
		method: String?,
		query: String?,
		payload: Data?,
		backgroundSession: URLSession?,
		responseHandler: ((_ received: Data?, _ error: Error?) -> Void)?)

	var completionHandler: ((Data?, URLResponse?, (any Error)?) -> Void)? { get set }

	var sdServerRequestTask: UIBackgroundTaskIdentifier? { get set }
}

extension SDNetworking {
	public func requestToSDServer(
		quiet: Bool = false,
		api_endpoint: SDAPIendpoint,
		method: String? = nil,
		query: String? = nil,
		payload: Data? = nil,
		backgroundSession: URLSession? = nil,
		responseHandler: ((_ received: Data?, _ error: Error?) -> Void)?) {
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
				responseHandler?(nil, nil)
				return
			}


			var httpRequest = URLRequest(url: requestURL)
			httpRequest.timeoutInterval = .infinity
			httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

			httpRequest.httpMethod = method ?? "GET"
			if payload != nil {	fxd_log()
				fxdPrint(name: "payload", dictionary: payload?.jsonObject() ?? [:])
				httpRequest.httpMethod = "POST"
				httpRequest.httpBody = payload
			}


			let completionHandler = {
				(data: Data?, response: URLResponse?, error: Error?) in

				fxdPrint("data: ", data, quiet:quiet)
				fxdPrint("error: ", error, quiet:quiet)
				guard let receivedData = data else {
					fxdPrint("httpRequest.url: ", httpRequest.url)
					fxdPrint("httpRequest.allHTTPHeaderFields: ", httpRequest.allHTTPHeaderFields)
					fxdPrint("httpRequest.httpMethod: ", httpRequest.httpMethod)
					fxdPrint("httpRequest.httpBody: ", httpRequest.httpBody)
					responseHandler?(nil, error)
					return
				}


				var modifiedError = error
				let httpResponse = response as? HTTPURLResponse
				let httpResponseCode = httpResponse?.statusCode ?? 200

				if modifiedError == nil,
				   httpResponse != nil,
				   httpResponseCode != 200 {
					fxdPrint("httpResponse: ", httpResponse)

					let jsonObject: [String:Any?]? = receivedData.jsonObject()

					var errorDescription = "Problem with server"
					switch httpResponseCode {
						case 404:
							errorDescription = "Possibly, your Stable Diffusion server is not operating."
						default:
							break
					}

					let errorFailureReason = jsonObject?["msg"] as? String
					let errorDetail = jsonObject?["detail"] as? String


					let responseUserInfo = [
						NSLocalizedDescriptionKey : errorDescription,
						NSLocalizedFailureReasonErrorKey : "\(errorFailureReason ?? "")\n\(errorDetail ?? "")"
					]

					modifiedError = NSError(
						domain: "SDEngine",
						code: httpResponseCode,
						userInfo: responseUserInfo)
				}

				responseHandler?(receivedData, modifiedError)
			}


			var httpTask: URLSessionDataTask? = nil
			if backgroundSession != nil {
				self.completionHandler = completionHandler
				httpTask = backgroundSession?.dataTask(with: httpRequest)
			}
			else {
				httpTask = URLSession.shared.dataTask(with: httpRequest, completionHandler: completionHandler)
			}
			httpTask?.resume()
		}
}
