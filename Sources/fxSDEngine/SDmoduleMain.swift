

import Foundation
import UIKit

import fXDKit


public protocol SDmoduleMain: SDNetworking, AnyObject {
	var systemInfo: SDcodableSysInfo? { get set }
	var generationPayload: SDcodablePayload? { get set }

	var progressObservable: SDcodableProgress? { get set }

	var shouldContinueRefreshing: Bool { get set }

	var displayedImage: UIImage? { get set }

	var isEngineRunning: Bool { get }

	var imageURLs: [URL]? { get set }


	func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_sysInfo(completionHandler: ((_ error: Error?)->Void)?)

	func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?)
	func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?)

	func execute_txt2img(backgroundSession: URLSession?, completionHandler: ((_ error: Error?)->Void)?)

	func execute_progress(skipImageDecoding: Bool, quiet: Bool, completionHandler: ((_ lastProgress: SDcodableProgress?, _ error: Error?)->Void)?)
	func continueRefreshing()
	func interrupt(completionHandler: ((_ error: Error?)->Void)?)
}


extension SDmoduleMain {
	public func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INTERNAL_SYSINFO) {
				[weak self] (data, error) in

				#if DEBUG
				if let jsonObject = data?.jsonObject(quiet: true) {
					fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonObject)
				}
				#endif

				guard let decodedResponse = data?.decode(SDcodableSysInfo.self) else {
					completionHandler?(error)
					return
				}

				self?.systemInfo = decodedResponse
				completionHandler?(error)
			}
	}

	public func refresh_sysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		execute_internalSysInfo {
			[weak self] (error) in

			// TODO: find better evaluation for NEWly started server
			guard let folderPath = self?.systemInfo?.generationFolder() else {
				DispatchQueue.main.async {
					self?.generationPayload = SDcodablePayload.minimalPayload()
					completionHandler?(error)
				}
				return
			}


			self?.obtain_latestPNGData(
				path: folderPath,
				completionHandler: {
					[weak self] (pngData, fullPath, error) in

					guard pngData != nil else {
						completionHandler?(error)
						return
					}

					guard let imagePath = fullPath else {
						completionHandler?(error)
						return
					}


					self?.prepare_generationPayload(
						pngData: pngData!,
						imagePath: imagePath) {
							error in

							if pngData != nil,
							   let latestImage = UIImage(data: pngData!) {
								DispatchQueue.main.async {
									self?.displayedImage = latestImage
								}
							}
							completionHandler?(error)
						}
				})
		}
	}
}

extension SDmoduleMain {
	public func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			query: "folder_path=\(path)") {
				[weak self] (data, error) in

				guard let decodedResponse = data?.decode(SDcodableFiles.self),
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
					self?.obtain_latestPNGData(
						path: fullpath,
						completionHandler: completionHandler)
					return
				}


				self?.requestToSDServer(
					api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
					query: "path=\(fullpath)&t=file") {
						(received, error) in

						guard let pngData = received else {
							completionHandler?(nil, fullpath, error)
							return
						}


						completionHandler?(pngData, fullpath, error)
					}
			}
	}

	public func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?) {
		let _assignPayload: (String, Error?) -> Void = {
			[weak self] (infotext: String, error: Error?) in

			guard !infotext.isEmpty, error == nil else {
				completionHandler?(error)
				return
			}

			guard let obtainedPayload = SDcodablePayload.decoded(infotext: infotext) else {
				completionHandler?(error)
				return
			}

			DispatchQueue.main.async {
				fxd_log()
				self?.generationPayload = obtainedPayload

				if let encodedPayload = obtainedPayload.encodedPayload() {
					SDmoduleStorage().savePayloadToFile(payload: encodedPayload)
				}

				completionHandler?(error)
			}
		}


		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			query: "path=\(imagePath)",
			responseHandler: {
				(received, error) in

				guard let receivedData = received,
					  let infotext = String(data: receivedData, encoding: .utf8)
				else {
					_assignPayload("", error)
					return
				}

				_assignPayload(infotext, error)
			})
	}
}

extension SDmoduleMain {
	public func execute_txt2img(backgroundSession: URLSession?, completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		let payload: Data? = generationPayload?.evaluatedPayload(extensions: systemInfo?.Extensions)
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: payload,
			backgroundSession: backgroundSession) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil,
				   var jsonObject = data!.jsonObject() {	fxd_log()
					jsonObject["images"] = ["<IMAGES ENCODED>"]
					fxdPrint(jsonObject)
				}
				#endif

				guard let decodedResponse = data?.decode(SDcodableGenerated.self) else {
					DispatchQueue.main.async {
						completionHandler?(error)
					}
					return
				}


				guard let encodedImageArray = decodedResponse.images,
					  encodedImageArray.count > 0 else {	fxd_log()
					fxdPrint("receivedData.jsonObject()\n", data?.jsonObject())
					completionHandler?(error)
					return
				}


				let pngDataArray: [Data] = encodedImageArray.map {
					return Data(base64Encoded: $0 ?? "") ?? Data()
				}
				guard pngDataArray.count > 0 else {
					completionHandler?(error)
					return
				}


				guard self?.progressObservable?.state?.interrupted ?? false == false else {	fxd_log()
					completionHandler?(error)
					return
				}



				let infotext = decodedResponse.infotext() ?? ""
				let newImage = UIImage(data: pngDataArray.last!)

				DispatchQueue.main.async {
					fxd_log()

					if !(infotext.isEmpty),
					   let newlyGeneratedPayload = SDcodablePayload.decoded(infotext: infotext) {
						self?.generationPayload = newlyGeneratedPayload

						if let encodedPayload = newlyGeneratedPayload.encodedPayload() {
							SDmoduleStorage().savePayloadToFile(payload: encodedPayload)
						}
					}

					if newImage != nil {
						self?.displayedImage = newImage
					}

					let storage = SDmoduleStorage()
					for (index, pngData) in pngDataArray.enumerated() {
						if let latestImageURL = storage.saveGeneratedImage(pngData: pngData, index: index) {
							self?.imageURLs?.insert(latestImageURL, at: 0)
						}
					}

					completionHandler?(error)
				}
			}
	}
}


extension SDmoduleMain {
	public func execute_progress(
		skipImageDecoding: Bool = false,
		quiet: Bool = false,
		completionHandler: ((_ lastProgress: SDcodableProgress?, _ error: Error?)->Void)?) {

		requestToSDServer(
			quiet: quiet,
			api_endpoint: .SDAPI_V1_PROGRESS) {
				[weak self] (data, error) in

				guard let decodedResponse = data?.decode(SDcodableProgress.self) else {
					completionHandler?(nil, error)
					return
				}


				DispatchQueue.main.async {
					self?.progressObservable = decodedResponse
					completionHandler?(decodedResponse, error)
				}
			}
	}

	public func continueRefreshing() {
		guard shouldContinueRefreshing else {
			return
		}


		execute_progress(
			skipImageDecoding: false,
			quiet: true,
			completionHandler: {
				[weak self] (lastProgress, error) in

				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					self?.continueRefreshing()
				}
		})
	}

	public func interrupt(completionHandler: ((_ error: Error?)->Void)?) {
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
}
