
import Foundation
import UIKit

import fXDKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"

	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
	case SDAPI_V1_INTERRUPT = "sdapi/v1/interrupt"
	case SDAPI_V1_OPTIONS = "sdapi/v1/options"
	case SDAPI_V1_MODELS = "sdapi/v1/sd-models"


	case INFINITE_IMAGE_BROWSING_FILES = "infinite_image_browsing/files"
	case INFINITE_IMAGE_BROWSING_FILE = "infinite_image_browsing/file"
	case INFINITE_IMAGE_BROWSING_GENINFO = "infinite_image_browsing/image_geninfo"
}


public protocol SDNetworking: NSObjectProtocol {
	var SD_SERVER_HOSTNAME: String { get }

	func requestToSDServer(
		quiet: Bool,
		api_endpoint: SDAPIendpoint,
		method: String?,
		query: String?,
		payload: Data?,
		responseHandler: ((_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void)?)
}

extension SDNetworking {
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
}


class SDError: NSError, @unchecked Sendable {
	class func processsed(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> SDError? {
		guard !(error is Self) else {
			return error as? Self
		}

		guard error != nil
				|| data != nil
				|| response != nil else {
			return error as? Self
		}

		let errorStatusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
		guard errorStatusCode != 200 else {
			return error as? Self
		}


		let assumedDescription = "Problem with server"
		var assumedFailureReason = ""
		switch errorStatusCode {
			case 404:
				assumedFailureReason = "Possibly, your Stable Diffusion server is not operating."
			default:
				break
		}


		let jsonDictionary: [String:Any?]? = data?.jsonDictionary()

		var errorDescription = (error as? NSError)?.localizedDescription ?? assumedDescription
		errorDescription += "\n\(jsonDictionary?["error"] as? String ?? "")"

		let receivedDetail = "\n\(jsonDictionary?["detail"] as? String ?? "")"
		if receivedDetail != errorDescription {
			errorDescription += receivedDetail
		}
		errorDescription = errorDescription.trimmingCharacters(in: .whitespacesAndNewlines)


		var errorFailureReason = (error as? NSError)?.localizedFailureReason ?? assumedFailureReason
		errorFailureReason += "\n\(jsonDictionary?["errors"] as? String ?? "")"
		
		var receivedMSG = "\n\(jsonDictionary?["msg"] as? String ?? "")"
		if receivedMSG.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			if let detail = jsonDictionary?["detail"] as? Array<Dictionary<String, Any>> {
				receivedMSG = "\n\(detail.first?["msg"] as? String ?? "")"
			}
		}
		if receivedMSG != errorFailureReason {
			errorFailureReason += receivedMSG
		}
		errorFailureReason = errorFailureReason.trimmingCharacters(in: .whitespacesAndNewlines)


		let errorUserInfo = [
			NSLocalizedDescriptionKey : errorDescription,
			NSLocalizedFailureReasonErrorKey : errorFailureReason
		]

		let processed = SDError(
			domain: "SDEngine",
			code: errorStatusCode,
			userInfo: errorUserInfo)


		fxd_log()
		fxdPrint(name: "DATA", dictionary: jsonDictionary)
		fxdPrint("RESPONSE", response)
		fxdPrint("ERROR", error)
		fxdPrint("PROCESSED", processed)

		return processed
	}
}


extension SDNetworking {
	func getRequest(api_endpoint: SDAPIendpoint) async -> [(Data, URLResponse)]? {
		let requestPath = "\(SD_SERVER_HOSTNAME)/\(api_endpoint.rawValue)"

		guard let requestURL = URL(string: requestPath) else {
			fxdPrint("requestPath: ", requestPath)
			return nil
		}


		var SD_RESPONSE: DataAndResponseActor? = nil
		let SD_REQUEST: URLRequest = URLRequest(url: requestURL)
		do {
			SD_RESPONSE = try await URLSession.shared.startSerializedURLRequest(urlRequests: [SD_REQUEST])
		}
		catch {
			fxdPrint(await SD_RESPONSE?.caughtError)
			fxdPrint(await SD_RESPONSE?.dataAndResponseTuples)
			return nil
		}


		return await SD_RESPONSE?.dataAndResponseTuples.count == 0 ? nil : SD_RESPONSE?.dataAndResponseTuples
	}
}
