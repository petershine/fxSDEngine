
import OSLog
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


protocol SDcodableResponse: Codable {
	static func decoded(_ receivedData: Data) -> (any SDcodableResponse)?
}

extension SDcodableResponse {
	static func decoded(_ receivedData: Data) -> (any SDcodableResponse)? {
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


public protocol SDprotocolProperties {
	var overlayObservable: FXDobservableOverlay? { get set }
	var progressObservable: SDcodableProgress? { get set }

	var displayedImage: UIImage? { get set }

	var shouldContinueRefreshing: Bool { get set }
}



open class FXDobservableSDProperties: SDprotocolProperties, ObservableObject {
	@Published open var overlayObservable: FXDobservableOverlay? = nil
	@Published open var progressObservable: SDcodableProgress? = nil

	@Published open var displayedImage: UIImage? = nil

	@Published open var shouldContinueRefreshing: Bool = false {
		didSet {
			if shouldContinueRefreshing == false {
				overlayObservable = nil
				progressObservable = nil
			}
		}
	}

	public init() {
		self.shouldContinueRefreshing = false
	}
}

open class FXDmoduleSDEngine: NSObject {
	@Published public var observable: FXDobservableSDProperties = FXDobservableSDProperties()

	fileprivate var systemInfo: SDcodableSysInfo? = nil

	public var currentGenerationPayload: SDcodablePayload? {
		didSet {
			if let encodedPayload = currentGenerationPayload?.encodedPayload() {
				savePayloadToFile(payload: encodedPayload)
			}
		}
	}


	open var savedPayloadFilename: String {
		return "savedPayload.json"
	}

	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}


	public init(observable: FXDobservableSDProperties? = nil) {
		super.init()

		self.observable = observable ?? FXDobservableSDProperties()
	}


	open func refresh_LastPayload(completionHandler: ((_ error: Error?)->Void)?) {
		execute_internalSysInfo {
			[weak self] (error) in

			guard let folderPath = self?.systemInfo?.generationFolder() else {
				// TODO: find better evaluation for NEWly started server
				do {
					self?.currentGenerationPayload = try JSONDecoder().decode(SDcodablePayload.self, from: "{}".data(using: .utf8) ?? Data())
				}
				catch {
					fxdPrint(error)
				}
				completionHandler?(error)
				return
			}


			self?.obtain_latestGenereatedImage(
				folderPath: folderPath,
				completionHandler: {
				[weak self] (latestImage, fullpath, error) in

					if let path = fullpath {
						self?.obtain_GenInfo(path: path, completionHandler: nil)
					}

					DispatchQueue.main.async {
						self?.observable.displayedImage = latestImage
					}
					completionHandler?(error)
			})
		}
	}

	open func obtain_GenInfo(path: String, completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			query: "path=\(path)",
			responseHandler: {
				[weak self] (received, error) in

				guard let receivedData = received,
					  let receivedString = String(data: receivedData, encoding: .utf8)
				else {
					completionHandler?(error)
					return
				}

				guard let decodedPayload = SDcodablePayload.decoded(infotext: receivedString) else {
					completionHandler?(error)
					return
				}

				fxd_log()
				self?.currentGenerationPayload = decodedPayload
				completionHandler?(error)
		})
	}

	open func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INTERNAL_SYSINFO) {
				[weak self] (data, error) in

				#if DEBUG
				if let jsonObject = data?.jsonObject(quiet: true) {
					fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonObject)
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = SDcodableSysInfo.decoded(receivedData) as? SDcodableSysInfo
				else {
					completionHandler?(error)
					return
				}

				self?.systemInfo = decodedResponse
				completionHandler?(error)
			}
	}

	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		let payload: Data? = currentGenerationPayload?.evaluatedPayload(extensions: systemInfo?.Extensions)
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: payload) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil,
				   var jsonObject = data!.jsonObject() {
					jsonObject["images"] = ["<IMAGES ENCODED>"]
					fxdPrint(jsonObject)
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = SDcodableGeneration.decoded(receivedData) as? SDcodableGeneration
				else {
					completionHandler?(error)
					return
				}


				let decodedImageArray = decodedResponse.decodedImages()

				guard let generated = decodedImageArray.first else {
					fxdPrint("receivedData.jsonObject()\n", receivedData.jsonObject())
					completionHandler?(error)
					return
				}


				if let infotext = decodedResponse.infotext(),
				   let decodedPayload = SDcodablePayload.decoded(infotext: infotext) {	fxd_log()
					self?.currentGenerationPayload = decodedPayload
				}

				DispatchQueue.main.async {
					self?.observable.displayedImage = generated
				}
				completionHandler?(error)
			}
	}

	open func execute_progress(skipImageDecoding: Bool, quiet: Bool = false, completionHandler: ((_ lastProgress: SDcodableProgress?, _ error: Error?)->Void)?) {
		requestToSDServer(
			quiet: quiet,
			api_endpoint: .SDAPI_V1_PROGRESS) {
				[weak self] (data, error) in

				guard let receivedData = data,
					  let decodedResponse = SDcodableProgress.decoded(receivedData) as? SDcodableProgress
				else {
					completionHandler?(nil, error)
					return
				}


				var progressImage: UIImage? = nil
				if !skipImageDecoding,
				   let imageEncoded = decodedResponse.current_image,
				   let decodedImage = imageEncoded.decodedImage() {
					progressImage = decodedImage
				}


				DispatchQueue.main.async {
					if progressImage != nil {
						self?.observable.displayedImage = progressImage
					}

					self?.observable.progressObservable = decodedResponse
				}
				completionHandler?(decodedResponse, error)
			}
	}

	open func continuousProgressRefreshing() {
		guard observable.shouldContinueRefreshing else {
			return
		}


		execute_progress(
			skipImageDecoding: false,
			quiet: true,
			completionHandler: {
			[weak self] (lastProgress, error) in

			self?.continuousProgressRefreshing()
		})
	}

	open func interrupt(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_INTERRUPT,
			method: "POST") {
				[weak self] (receivedData, error) in

				self?.execute_progress(
					skipImageDecoding: true,
					quiet: true,
					completionHandler: {
						lastProgress, error in

						fxdPrint("[lastProgress?.state]: ", lastProgress?.state)
						completionHandler?(error)
					})
			}
	}

	open func obtain_latestGenereatedImage(folderPath: String, completionHandler: ((_ image: UIImage?, _ path: String?, _ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			query: "folder_path=\(folderPath)") {
				[weak self] (data, error) in

				guard let receivedData = data,
					  let decodedResponse = SDcodableFiles.decoded(receivedData) as? SDcodableFiles,
					  let filesORfolders = decodedResponse.files
				else {
					completionHandler?(nil, nil, error)
					return
				}

				fxdPrint("filesORfolders.count: ", filesORfolders.count)

				let latestFileORfolder = filesORfolders
					.sorted {
						($0?.updated_time())! > ($1?.updated_time())!
					}
					.filter { 
						!($0?.fullpath?.contains("DS_Store") ?? false)
					}
					.first as? SDcodableFile

				fxdPrint("latestFileORfolder?.updated_time(): ", latestFileORfolder?.updated_time())
				fxdPrint("latestFileORfolder?.fullpath: ", latestFileORfolder?.fullpath)
				guard latestFileORfolder != nil,
					  let fullpath = latestFileORfolder?.fullpath
				else {
					completionHandler?(nil, nil, error)
					return
				}


				fxdPrint("latestFileORfolder?.type: ", latestFileORfolder?.type)
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
							completionHandler?(nil, fullpath, error)
							return
						}


						let latestImage = UIImage(data: receivedData)

						completionHandler?(latestImage, fullpath, error)
					}
			}
	}
}


extension FXDmoduleSDEngine {
	func requestToSDServer(
		quiet: Bool = false,
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


extension FXDmoduleSDEngine {
	@objc open func savePayloadToFile(payload: Data) {
		guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {	fxd_log()
			fxdPrint("Document directory not found")
			return
		}

		let fileURL = documentDirectory.appendingPathComponent(savedPayloadFilename)
		do {
			try payload.write(to: fileURL)
			fxdPrint("[DATA SAVED]: ", fileURL)
		} catch {	fxd_log()
			fxdPrint("payload: ", payload)
			fxdPrint("Failed to save: ", error)
		}
	}

	@objc open func loadPayloadFromFile() -> Data? {
		guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {	fxd_log()
			fxdPrint("Document directory not found")
			return nil
		}


		var payloadData: Data? = nil
		let fileURL = documentDirectory.appendingPathComponent(savedPayloadFilename)
		do {
			payloadData = try Data(contentsOf: fileURL)
		} catch {	fxd_log()
			fxdPrint("Failed to load: ", error)
		}

		return payloadData
	}
}
