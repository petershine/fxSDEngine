

import Foundation
import UIKit

import fXDKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"
	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
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

	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}

	open var currentPayload: Data? {
		return nil
	}

	override public init() {
		super.init()
	}


	private func requestToSDServer(api_endpoint: SDAPIendpoint, payload: Data?, responseHandler: ((_ jsonObject: Any?, _ error: Error?) -> Void)?) {
		let requestPath = "\(SD_SERVER_HOSTNAME)/\(api_endpoint.rawValue)"

		fxdPrint("requestPath: \(requestPath)")
		guard let requestURL = URL(string: requestPath) else {
			responseHandler?(nil, nil)
			return
		}


		var httpRequest = URLRequest(url: requestURL)
		httpRequest.timeoutInterval = .infinity
		httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

		httpRequest.httpMethod = "GET"
		if payload != nil {
			httpRequest.httpMethod = "POST"
			httpRequest.httpBody = payload
		}


		let httpTask = URLSession.shared.dataTask(with: httpRequest) {
			(data: Data?, response: URLResponse?, error: Error?) in

			fxdPrint("data: \(String(describing: data))")
			fxdPrint("response: \(String(describing: response))")
			fxdPrint("error: \(String(describing: error))")
			guard let receivedData = data else {
				responseHandler?(nil, error)
				return
			}


			var jsonObject: Any? = nil
			do {
				jsonObject = try JSONSerialization.jsonObject(with: receivedData, options: .mutableContainers)
			}
			catch let jsonError {
				fxdPrint("jsonError: \(jsonError)")
			}

			fxdPrint("jsonObject: \(String(describing: jsonObject))")

			var revisedError = error
			if revisedError == nil,
			   let responseCode = (response as? HTTPURLResponse)?.statusCode, responseCode != 200,
			   let jsonMessage = ((jsonObject as? Dictionary<String, Any>)?["msg"] as? String), !(jsonMessage.isEmpty) {
				revisedError = NSError(domain: "SDEngine", code: responseCode, userInfo: [NSLocalizedDescriptionKey:jsonMessage])
			}

			responseHandler?(jsonObject, revisedError)
		}
		httpTask.resume()
	}


	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(api_endpoint: .SDAPI_V1_TXT2IMG,
						  payload: currentPayload) {
			[weak self] (jsonObject: Any?, error: Error?) in

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
			[weak self] (jsonObject, error) in

			let current_image = (jsonObject as? Dictionary<String, Any?>)?[Self.OBJKEY_CURRENT_IMAGE]
			let imagesEncoded = [current_image] as? Array<String>

			let decodedImageArray = self?.decodedImages(imagesEncoded: imagesEncoded ?? [])

			if let availableImage = decodedImageArray?.first {
				DispatchQueue.main.async {
					self?.generatedImage = availableImage
				}
			}

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
