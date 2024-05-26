

import Foundation
import UIKit

import fXDKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"
	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
	case SDAPI_V1_INTERRUPT = "sdapi/v1/interrupt"
}

public struct SDdecodedProgress: Codable {
	var progress: Double? = 0.0
	var eta_relative: Double? = 0.0

	var textinfo: String? = nil

	var current_image: String? = nil
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


@available(iOS 17.0, *)
open class FXDmoduleSDEngine: NSObject, ObservableObject {
	private static let OBJKEY_IMAGES = "images"
	private static let OBJKEY_CURRENT_IMAGE = "current_image"

	@Published open var generatedImage: UIImage? = nil
	@Published open var generationProgress: Double = 0.0
	@Published open var shouldContinueRefreshing: Bool = false


	open var savedPayloadFilename: String {
		return ""
	}

	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}

	open var currentPayload: Data? {
		return nil
	}

	override public init() {
		super.init()
	}


	private func requestToSDServer(api_endpoint: SDAPIendpoint, method: String? = nil, payload: Data?, responseHandler: ((_ received: Data?, _ jsonObject: Any?, _ error: Error?) -> Void)?) {
		let requestPath = "\(SD_SERVER_HOSTNAME)/\(api_endpoint.rawValue)"

		fxdPrint("requestPath: \(requestPath)")
		guard let requestURL = URL(string: requestPath) else {
			responseHandler?(nil, nil, nil)
			return
		}


		var httpRequest = URLRequest(url: requestURL)
		httpRequest.timeoutInterval = .infinity
		httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

		httpRequest.httpMethod = method ?? "GET"
		if method == nil && payload != nil {
			httpRequest.httpMethod = "POST"
			httpRequest.httpBody = payload
		}

		fxdPrint("httpRequest.url: \(String(describing: httpRequest.url))")
		fxdPrint("httpRequest.allHTTPHeaderFields: \(String(describing: httpRequest.allHTTPHeaderFields))")
		fxdPrint("httpRequest.httpMethod: \(String(describing: httpRequest.httpMethod))")

		let httpTask = URLSession.shared.dataTask(with: httpRequest) {
			(data: Data?, response: URLResponse?, error: Error?) in

			fxdPrint("data: \(String(describing: data))")
			fxdPrint("response: \(String(describing: response))")
			fxdPrint("error: \(String(describing: error))")
			guard let receivedData = data else {
				responseHandler?(nil, nil, error)
				return
			}


			var jsonObject: Dictionary<String, Any?>? = nil
			do {
				jsonObject = try JSONSerialization.jsonObject(with: receivedData, options: .mutableContainers) as? Dictionary<String, Any?>
			}
			catch let jsonError {
				fxdPrint("jsonError: \(jsonError)")
			}


			var modifiedError = error
			if modifiedError == nil,
			   let responseCode = (response as? HTTPURLResponse)?.statusCode, responseCode != 200 {
				fxdPrint("jsonObject: \(String(describing: jsonObject))")
				
				let responseMSG = jsonObject?["msg"] as? String
				let responseDetail = jsonObject?["detail"] as? String


				let responseUserInfo = [NSLocalizedDescriptionKey : "\(responseMSG ?? "")\n\(responseDetail ?? "")"]

				modifiedError = NSError(
					domain: "SDEngine",
					code: responseCode,
					userInfo: responseUserInfo)
			}

			responseHandler?(receivedData, jsonObject, modifiedError)
		}
		httpTask.resume()
	}


	open func savePayloadToFile(payload: String) {
		if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
			let fileURL = documentDirectory.appendingPathComponent(savedPayloadFilename)

			do {
				if let processed: Data = payload.processedJSONData() {
					fxdPrint("payload: \(payload)")
					try processed.write(to: fileURL)
					fxdPrint("Text successfully saved to \(fileURL)")
				}
			} catch {
				fxdPrint("Error saving text: \(error)")
			}
		}
	}

	open func loadPayloadFromFile() -> String? {
		guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
			fxdPrint("Document directory not found")
			return nil
		}


		let fileURL = documentDirectory.appendingPathComponent(savedPayloadFilename)
		do {
			let content = try String(contentsOf: fileURL, encoding: .utf8)
			return content
		} catch {
			fxdPrint("Failed to load file: \(error)")
			return nil
		}
	}


	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(api_endpoint: .SDAPI_V1_TXT2IMG,
						  method: "POST",
						  payload: currentPayload) {
			[weak self] (receivedData, jsonObject, error) in

			let imagesEncoded = (jsonObject as? Dictionary<String, Any?>)?[Self.OBJKEY_IMAGES] as? Array<String>

			let decodedImageArray = self?.decodedImages(imagesEncoded: imagesEncoded ?? [])

			if let availableImage = decodedImageArray?.first {
				DispatchQueue.main.async {
					self?.generatedImage = availableImage
				}
			}

			completionHandler?(error)
		}
	}

	open func execute_progress(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(api_endpoint: .SDAPI_V1_PROGRESS, payload: nil) {
			[weak self] (receivedData, jsonObject, error) in

			guard let receivedData else {
				completionHandler?(error)
				return
			}


			var decodedProgress: SDdecodedProgress? = nil
			do {
				decodedProgress = try JSONDecoder().decode(SDdecodedProgress.self, from: receivedData)
				fxdPrint("[decodedProgress] \(String(describing: decodedProgress?.progress))")
			}
			catch let decodeException {
				fxdPrint("decodeException: \(String(describing: decodeException))")
			}

			guard decodedProgress != nil,
				  let current_image = decodedProgress!.current_image else {
				completionHandler?(error)
				return
			}


			let imagesEncoded = [current_image] as? Array<String>

			let decodedImageArray = self?.decodedImages(imagesEncoded: imagesEncoded ?? [])

			if let availableImage = decodedImageArray?.first {
				DispatchQueue.main.async {
					self?.generatedImage = availableImage
					self?.generationProgress = decodedProgress?.progress ?? 0.0
				}
			}

			completionHandler?(error)
		}
	}

	open func continuousProgressRefreshing() {
		guard shouldContinueRefreshing else {
			return
		}


		execute_progress {
			[weak self] (error) in

			self?.continuousProgressRefreshing()
		}
	}

	open func interrupt(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_INTERRUPT,
			method: "POST",
			payload: nil) {
				(receivedData, jsonObject, error) in

				completionHandler?(error)
			}
	}
}


extension FXDmoduleSDEngine {
	func decodedImages(imagesEncoded: Array<String>) -> [UIImage] {
		fxdPrint("[STARTED DECODING]: \(String(describing: imagesEncoded.count)) image(s)")

		var decodedImageArray: [UIImage] = []
		for base64string in imagesEncoded {
			guard let imageData = Data(base64Encoded: base64string) else {
				continue
			}
			fxdPrint("imageData byte count: \(imageData.count)")

			guard let decodedImage = UIImage(data: imageData) else {
				continue
			}
			fxdPrint("decodedImage: \(decodedImage)")

			decodedImageArray.append(decodedImage)
		}

		return decodedImageArray
	}
}
