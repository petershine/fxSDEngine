

import Foundation
import UIKit

import fXDKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"

	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PNG_INFO = "sdapi/v1/png-info"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
	case SDAPI_V1_INTERRUPT = "sdapi/v1/interrupt"

	case INFINITE_IMAGE_BROWSING_FILES = "infinite_image_browsing/files"
	case INFINITE_IMAGE_BROWSING_FILE = "infinite_image_browsing/file"
}

public struct SDencodablePayload: Encodable {
	var image: String? = nil

	public init(image: String?) {
		self.image = image
	}
}

public struct SDcodableResponse: Codable {
	var progress: Double? = nil
	var eta_relative: Double? = nil

	var textinfo: String? = nil

	var current_image: String? = nil
	var images: [String?]? = nil


	var Config: SDcodableConfig? = nil
	struct SDcodableConfig: Codable {
		var outdir_samples: String? = nil
	}


	var files: [SDcodableFile?]? = nil
	struct SDcodableFile: Codable {
		var type: String? = nil
		var size: String? = nil
		var name: String? = nil
		var fullpath: String? = nil
		var is_under_scanned_path: Bool? = nil
		var date: String? = nil
		var created_time: String? = nil

		func updated_time() -> Date? {
			guard date != nil else {
				return nil
			}

			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
			return dateFormatter.date(from:date!)
		}
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
			api_endpoint: .INTERNAL_SYSINFO) {
				[weak self] (receivedData, error) in

				guard let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let Config = decodedResponse.Config 
				else {
					completionHandler?(error)
					return
				}


				self?.generationFolder = Config.outdir_samples ?? ""
				fxdPrint("self?.generationFolder: \(String(describing: self?.generationFolder))")

				completionHandler?(error)
			}
	}


	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: currentPayload) {
				[weak self] (receivedData, error) in

				guard let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let images = decodedResponse.images 
				else {
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
			api_endpoint: .SDAPI_V1_PROGRESS) {
				[weak self] (receivedData, error) in

				guard let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let current_image = decodedResponse.current_image
				else {
					completionHandler?(error)
					return
				}


				let imagesEncoded = [current_image] as? Array<String>

				let decodedImageArray = self?.decodedImages(imagesEncoded: imagesEncoded ?? [])

				if let availableImage = decodedImageArray?.first {
					DispatchQueue.main.async {
						self?.generatedImage = availableImage
						self?.generationProgress = decodedResponse.progress ?? 0.0
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
			method: "POST") {
				(receivedData, error) in

				completionHandler?(error)
			}
	}

	open func obtain_latestGenereatedImage(folderPath: String, completionHandler: ((_ image: UIImage?, _ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			query: "folder_path=\(folderPath)") {
				[weak self] (receivedData, error) in

				guard let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let filesORfolders = decodedResponse.files
				else {
					completionHandler?(nil, error)
					return
				}

				fxdPrint("filesORfolders: \(filesORfolders.count)")

				let latestFileORfolder = filesORfolders.sorted {
					($0?.updated_time())! > ($1?.updated_time())!
				}.first as? SDcodableResponse.SDcodableFile 

				fxdPrint("latestFileORfolder?.updated_time(): \(String(describing: latestFileORfolder?.updated_time()))")
				fxdPrint("latestFileORfolder?.fullpath: \(String(describing: latestFileORfolder?.fullpath))")
				guard latestFileORfolder != nil,
					  let fullpath = latestFileORfolder?.fullpath
				else {
					completionHandler?(nil, error)
					return
				}


				fxdPrint("latestFileORfolder?.type: \(String(describing: latestFileORfolder?.type))")
				guard let type = latestFileORfolder?.type,
						  type != "dir"
				else {
					//recursive
					self?.obtain_latestGenereatedImage(
						folderPath: fullpath,
						completionHandler: completionHandler)
					return
				}


				self?.requestToSDServer(
					api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
					query: "path=\(fullpath)&t=file") {
						(received, error) in

						guard let receivedData = received else {
							completionHandler?(nil, error)
							return
						}


						let latestImage = UIImage(data: receivedData)

						completionHandler?(latestImage, error)
					}
			}
	}
}


extension FXDmoduleSDEngine {
	func decodedResponse(receivedData: Data?) -> SDcodableResponse? {
		guard let receivedData else {
			return nil
		}


		var decodedResponse: SDcodableResponse? = nil
		do {
			decodedResponse = try JSONDecoder().decode(SDcodableResponse.self, from: receivedData)
		}
		catch let decodeException {
			fxdPrint("decodeException: \(String(describing: decodeException))")

			let _ = decodedJSONobject(receivedData: receivedData)
		}

		return decodedResponse
	}

	func decodedImages(imagesEncoded: [String?]) -> [UIImage] {
		fxdPrint("[STARTED DECODING]: \(String(describing: imagesEncoded.count)) image(s)")

		var decodedImageArray: [UIImage] = []
		for base64string in imagesEncoded {
			guard base64string != nil, !(base64string!.isEmpty) else {
				continue
			}


			guard let imageData = Data(base64Encoded: base64string!, options: .ignoreUnknownCharacters) else {
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

	public func decodedJSONobject(receivedData: Data) -> Dictionary<String, Any?>? {
		var jsonObject: Dictionary<String, Any?>? = nil
		do {
			jsonObject = try JSONSerialization.jsonObject(with: receivedData, options: .mutableContainers) as? Dictionary<String, Any?>
			fxdPrint("jsonObject: \(String(describing: jsonObject))")
		}
		catch let jsonError {
			let receivedString = String(data: receivedData, encoding: .utf8)
			fxdPrint("receivedString: \(String(describing: receivedString))")
			fxdPrint("jsonError: \(jsonError)")
		}

		return jsonObject
	}
}


extension FXDmoduleSDEngine {
	public func requestToSDServer(
		api_endpoint: SDAPIendpoint,
		method: String? = nil,
		query: String? = nil,
		payload: Data? = nil,
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
			if payload != nil {
				httpRequest.httpMethod = "POST"
				httpRequest.httpBody = payload
			}

			fxdPrint("httpRequest.url: \(String(describing: httpRequest.url))")
			fxdPrint("httpRequest.allHTTPHeaderFields: \(String(describing: httpRequest.allHTTPHeaderFields))")
			fxdPrint("httpRequest.httpMethod: \(String(describing: httpRequest.httpMethod))")
			fxdPrint("httpRequest.httpBody: \(String(describing: httpRequest.httpBody))")

			let httpTask = URLSession.shared.dataTask(with: httpRequest) {
				[weak self] (data: Data?, response: URLResponse?, error: Error?) in

				fxdPrint("data: \(String(describing: data))")
				fxdPrint("response: \(String(describing: response))")
				fxdPrint("error: \(String(describing: error))")
				guard let receivedData = data else {
					responseHandler?(nil, error)
					return
				}


				var modifiedError = error
				if modifiedError == nil,
				   let responseCode = (response as? HTTPURLResponse)?.statusCode, responseCode != 200 {

					let jsonObject = self?.decodedJSONobject(receivedData: receivedData)

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
