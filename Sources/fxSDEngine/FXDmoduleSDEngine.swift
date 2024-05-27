

import Foundation
import UIKit

import fXDKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"
	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
	case SDAPI_V1_INTERRUPT = "sdapi/v1/interrupt"

	case INFINITE_IMAGE_BROWSING_FILES = "infinite_image_browsing/files"
}

public struct SDdecodedResponse: Codable {
	var Config: SDdecodedConfig? = nil

	var progress: Double? = 0.0
	var eta_relative: Double? = 0.0

	var textinfo: String? = nil

	var current_image: String? = nil
	var images: [String?]? = nil

	struct SDdecodedConfig: Codable {
		var outdir_samples: String? = nil
	}
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

	open var generationFolder: String? = nil

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

		execute_internalSysInfo { 
			error in
			
			self.execute_infiniteImageBrowsing_Files {
				error in

			}
		}
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


	open func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INTERNAL_SYSINFO,
			payload: nil) {
				[weak self] (receivedData, error) in

				guard let receivedData else {
					completionHandler?(error)
					return
				}


				var decodedResponse: SDdecodedResponse? = nil
				do {
					decodedResponse = try JSONDecoder().decode(SDdecodedResponse.self, from: receivedData)
				}
				catch let decodeException {
					fxdPrint("decodeException: \(String(describing: decodeException))")
				}

				guard decodedResponse != nil,
					  let Config = decodedResponse!.Config else {
					completionHandler?(error)
					return
				}


				self?.generationFolder = Config.outdir_samples
				fxdPrint("self?.generationFolder: \(String(describing: self?.generationFolder))")

				completionHandler?(error)
			}
	}


	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: currentPayload) {
				[weak self] (receivedData, error) in

				guard let receivedData else {
					completionHandler?(error)
					return
				}


				var decodedResponse: SDdecodedResponse? = nil
				do {
					decodedResponse = try JSONDecoder().decode(SDdecodedResponse.self, from: receivedData)
				}
				catch let decodeException {
					fxdPrint("decodeException: \(String(describing: decodeException))")
				}

				guard decodedResponse != nil,
					  let images = decodedResponse!.images else {
					completionHandler?(error)
					return
				}


				let decodedImageArray = self?.decodedImages(imagesEncoded: images)

				if let availableImage = decodedImageArray?.first {
					DispatchQueue.main.async {
						self?.generatedImage = availableImage
					}
				}

				completionHandler?(error)
			}
	}

	open func execute_progress(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_PROGRESS,
			payload: nil) {
				[weak self] (receivedData, error) in

				guard let receivedData else {
					completionHandler?(error)
					return
				}


				var decodedResponse: SDdecodedResponse? = nil
				do {
					decodedResponse = try JSONDecoder().decode(SDdecodedResponse.self, from: receivedData)
				}
				catch let decodeException {
					fxdPrint("decodeException: \(String(describing: decodeException))")
				}

				guard decodedResponse != nil,
					  let current_image = decodedResponse!.current_image else {
					completionHandler?(error)
					return
				}


				let imagesEncoded = [current_image] as? Array<String>

				let decodedImageArray = self?.decodedImages(imagesEncoded: imagesEncoded ?? [])

				if let availableImage = decodedImageArray?.first {
					DispatchQueue.main.async {
						self?.generatedImage = availableImage
						self?.generationProgress = decodedResponse?.progress ?? 0.0
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
				(receivedData, error) in

				completionHandler?(error)
			}
	}

	open func execute_infiniteImageBrowsing_Files(completionHandler: ((_ error: Error?)->Void)?) {
		guard let generationFolder = self.generationFolder else {
			assert(self.generationFolder != nil, "[SHOULD NOT BE nil] self.generationFolder: \(self.generationFolder)")
			return
		}

		requestToSDServer(
			api_endpoint: .SDAPI_V1_PROGRESS,
			query: "folder_path=\(self.generationFolder!)",
			payload: nil) {
				(receivedData, error) in

				completionHandler?(error)
			}
	}

	//infinite_image_browsing/files?folder_path
}


extension FXDmoduleSDEngine {
	func decodedImages(imagesEncoded: [String?]) -> [UIImage] {
		fxdPrint("[STARTED DECODING]: \(String(describing: imagesEncoded.count)) image(s)")

		var decodedImageArray: [UIImage] = []
		for base64string in imagesEncoded {
			guard base64string != nil, !(base64string!.isEmpty) else {
				continue
			}

			guard let imageData = Data(base64Encoded: base64string!) else {
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


private extension FXDmoduleSDEngine {
	private func requestToSDServer(
		api_endpoint: SDAPIendpoint,
		method: String? = nil,
		query: String? = nil,
		payload: Data?,
		responseHandler: ((_ received: Data?, _ error: Error?) -> Void)?) {

			var requestPath = "\(SD_SERVER_HOSTNAME)/\(api_endpoint.rawValue)"
			if !(query?.isEmpty ?? true),
			   let escapedQuery = query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
				requestPath += "?\(escapedQuery)"
			}
			fxdPrint("requestPath: \(requestPath)")

		guard let requestURL = URL(string: requestPath) else {
			responseHandler?(nil, nil)
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
				responseHandler?(nil, error)
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

			responseHandler?(receivedData, modifiedError)
		}
		httpTask.resume()
	}
}
