
import Foundation

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


public protocol SDnetworking {
	var SD_SERVER_HOSTNAME: String { get }
	
	var savedPayloadJSONurl: URL? { get }
	var savedImageFileURL: URL? { get }
	var sharableItem: Any? { get }

	func savePayloadToFile(payload: Data)
	func loadPayloadFromFile() -> Data?
	func saveGeneratedImage(pngData: Data) async throws -> Bool

	func requestToSDServer(
		quiet: Bool,
		api_endpoint: SDAPIendpoint,
		method: String?,
		query: String?,
		payload: Data?,
		responseHandler: ((_ received: Data?, _ error: Error?) -> Void)?)
}

extension SDnetworking {
	public var savedPayloadJSONurl: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		let fileURL = documentDirectory?.appendingPathComponent("savedPayload.json")
		return fileURL
	}

	public var savedImageFileURL: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		let fileURL = documentDirectory?.appendingPathComponent("savedImage.png")
		return fileURL
	}

	public var sharableItem: Any? {
		return savedImageFileURL
	}
}


extension SDnetworking {
	public func savePayloadToFile(payload: Data) {	fxd_log()
		fxdPrint("payload: ", payload)
		guard let fileURL = savedPayloadJSONurl else {
			return
		}

		do {
			try payload.write(to: fileURL)
			fxdPrint("[PAYLOAD JSON SAVED]: ", fileURL)
		} catch {
			fxdPrint(error)
		}
	}

	public func loadPayloadFromFile() -> Data? {
		guard let fileURL = savedPayloadJSONurl else {
			return nil
		}


		var payloadData: Data? = nil
		do {
			payloadData = try Data(contentsOf: fileURL)
		} catch {	fxd_log()
			fxdPrint(error)
		}

		return payloadData
	}

	public func saveGeneratedImage(pngData: Data) async -> Bool {	fxd_log()
		fxdPrint("pngData: ", pngData)
		guard let fileURL = savedImageFileURL else {
			return false
		}

		do {
			try pngData.write(to: fileURL)
			fxdPrint("[IMAGE FILE SAVED]: ", fileURL)
			return true

		} catch {
			fxdPrint(error)
			return false
		}
	}
}


extension SDnetworking {
	public func requestToSDServer(
		quiet: Bool = false,
		api_endpoint: SDAPIendpoint,
		method: String? = nil,
		query: String? = nil,
		payload: Data? = nil,
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


			let httpTask = URLSession.shared.dataTask(with: httpRequest) {
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
			httpTask.resume()
		}
}