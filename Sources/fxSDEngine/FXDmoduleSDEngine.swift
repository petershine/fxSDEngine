

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


public protocol SDprotocolProperties {
	var displayedImage: UIImage? { get set }

	var overlayObservable: FXDobservableOverlay? { get set }

	var progressValue: Double? { get set }
	var progressImage: UIImage? { get set }
	var shouldContinueRefreshing: Bool { get set }

	var isJobRunning: Bool { get set }
}



open class FXDobservableSDProperties: SDprotocolProperties, ObservableObject {
	@Published open var displayedImage: UIImage? = nil

	@Published open var overlayObservable: FXDobservableOverlay? = nil

	@Published open var progressValue: Double? = nil
	@Published open var progressImage: UIImage? = nil
	@Published open var shouldContinueRefreshing: Bool {
		didSet {
			if shouldContinueRefreshing == false {
				overlayObservable = nil
				progressValue = nil
				progressImage = nil
			}
		}
	}

	@Published open var isJobRunning: Bool = false

	public init() {
		self.shouldContinueRefreshing = false
	}
}

open class FXDmoduleSDEngine: NSObject {
	@Published public var observable: FXDobservableSDProperties = FXDobservableSDProperties()

	open var generationFolder: String? = nil

	open var savedPayloadFilename: String {
		return "savedPayload.json"
	}

	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}

	open var currentPayload: Data? {
		do {
			let payload = try loadPayloadFromFile()
			fxdPrint(String(data: payload!, encoding: .utf8) as Any)
			return payload
		} catch {
			fxdPrint("Error reading JSON object: \(error)")
			return nil
		}
	}

	public init(observable: FXDobservableSDProperties? = nil) {
		super.init()

		self.observable = observable ?? FXDobservableSDProperties()
	}


	open func savePayloadToFile(payload: Data) {
		guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
			fxdPrint("Document directory not found")
			return
		}

		let fileURL = documentDirectory.appendingPathComponent(savedPayloadFilename)
		do {
			try payload.write(to: fileURL)
			fxdPrint("[DATA SAVED]: \(fileURL)")
		} catch {
			fxdPrint("payload: \(payload)")
			fxdPrint("Failed to save: \(error)")
		}
	}

	open func loadPayloadFromFile() throws -> Data? {
		guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
			fxdPrint("Document directory not found")
			return nil
		}


		let fileURL = documentDirectory.appendingPathComponent(savedPayloadFilename)
		do {
			let payloadData = try Data(contentsOf: fileURL)
			return payloadData
		} catch {
			fxdPrint("Failed to load: \(error)")
			throw error
		}
	}


	open func refresh_LastPayload(completionHandler: ((_ error: Error?)->Void)?) {
		execute_internalSysInfo {
			[weak self] (error) in

			guard let folderPath = self?.generationFolder else {
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

				guard let receivedData = received else {
					completionHandler?(error)
					return
				}

				guard let encodablePayload = self?.encodeGenerationPayload(receivedData: receivedData) else {
					completionHandler?(error)
					return
				}

				guard let generationInfo = encodablePayload.generationInfo() else {
					completionHandler?(error)
					return
				}


				fxdPrint(String(data: generationInfo, encoding: .utf8) as Any, quiet: true)
				self?.savePayloadToFile(payload: generationInfo)
				completionHandler?(error)
		})
	}

	open func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INTERNAL_SYSINFO) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil {
					let jsonObject = self?.decodedJSONobject(receivedData: data!, quiet: true)
					fxdPrint("[INTERNAL_SYSINFO]:\n\(String(describing: jsonObject))")
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let Config = decodedResponse.Config
				else {
					completionHandler?(error)
					return
				}


				self?.generationFolder = Config.outdir_samples
				completionHandler?(error)
			}
	}

	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: currentPayload) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil {
					self?.fxdebug(data: data!)
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let images = decodedResponse.images
				else {
					completionHandler?(error)
					return
				}


				let decodedImageArray = self?.decodedImages(imagesEncoded: images)

				guard let generated = decodedImageArray?.first else {
					completionHandler?(error)
					return
				}


				DispatchQueue.main.async {
					self?.observable.displayedImage = generated
				}
				completionHandler?(error)
			}
	}

	open func execute_progress(skipImageDecoding: Bool, quiet: Bool = false, completionHandler: ((_ lastProgress: SDcodableResponse?, _ error: Error?)->Void)?) {
		requestToSDServer(
			quiet: quiet,
			api_endpoint: .SDAPI_V1_PROGRESS) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil {
					var jsonObject = self?.decodedJSONobject(receivedData: data!, quiet: true)
					jsonObject?["current_image"] = "<IMAGE base64 string>"
					fxdPrint("[PROGRESS]:\n\(String(describing: jsonObject))", quiet: true)
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = self?.decodedResponse(receivedData: receivedData)
				else {
					completionHandler?(nil, error)
					return
				}


				var progressImage: UIImage? = nil
				if !skipImageDecoding,
				   let current_image = decodedResponse.current_image,
				   let imagesEncoded = [current_image] as? Array<String>,
				   let decodedImageArray = self?.decodedImages(imagesEncoded: imagesEncoded, quiet:quiet) {
					progressImage = decodedImageArray.first
				}


				DispatchQueue.main.async {
					if progressImage != nil {
						self?.observable.displayedImage = progressImage
						self?.observable.progressImage = progressImage
					}

					self?.observable.progressValue = decodedResponse.progress

					self?.observable.isJobRunning = decodedResponse.state?.isJobRunning() ?? false
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

						fxdPrint("[lastProgress?.state]: \(lastProgress?.state)")
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
					  let decodedResponse = self?.decodedResponse(receivedData: receivedData),
					  let filesORfolders = decodedResponse.files
				else {
					completionHandler?(nil, nil, error)
					return
				}

				fxdPrint("filesORfolders: \(filesORfolders.count)")

				let latestFileORfolder = filesORfolders
					.sorted {
						($0?.updated_time())! > ($1?.updated_time())!
					}
					.filter { 
						!($0?.fullpath?.contains("DS_Store") ?? false)
					}
					.first as? SDcodableResponse.SDcodableFile

				fxdPrint("latestFileORfolder?.updated_time(): \(String(describing: latestFileORfolder?.updated_time()))")
				fxdPrint("latestFileORfolder?.fullpath: \(String(describing: latestFileORfolder?.fullpath))")
				guard latestFileORfolder != nil,
					  let fullpath = latestFileORfolder?.fullpath
				else {
					completionHandler?(nil, nil, error)
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
			fxdPrint("requestPath: \(requestPath)", quiet:quiet)

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


			let httpTask = URLSession.shared.dataTask(with: httpRequest) {
				[weak self] (data: Data?, response: URLResponse?, error: Error?) in

				fxdPrint("data: \(String(describing: data))", quiet:quiet)
				fxdPrint("error: \(String(describing: error))", quiet:quiet)
				guard let receivedData = data else {
					fxdPrint("httpRequest.url: \(String(describing: httpRequest.url))")
					fxdPrint("httpRequest.allHTTPHeaderFields: \(String(describing: httpRequest.allHTTPHeaderFields))")
					fxdPrint("httpRequest.httpMethod: \(String(describing: httpRequest.httpMethod))")
					fxdPrint("httpRequest.httpBody: \(String(describing: httpRequest.httpBody))")
					responseHandler?(nil, error)
					return
				}


				var modifiedError = error
				if modifiedError == nil,
				   let responseCode = (response as? HTTPURLResponse)?.statusCode, responseCode != 200 {
					fxdPrint("response: \(String(describing: response))")

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
