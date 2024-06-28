

import Foundation
import UIKit

import fXDKit


public protocol SDmoduleMain: NSObject {
	var networkingModule: SDNetworking { get set }

	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableModel]? { get set }
	var generationPayload: SDcodablePayload? { get set }

	var use_lastSeed: Bool { get set }
	var use_adetailer: Bool { get set }

	var progressObservable: SDcodableProgress? { get set }
	var isSystemBusy: Bool { get set }

	var displayedImage: UIImage? { get set }


	func synchronize_withSystem(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_systemInfo(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_systemCheckpoints(completionHandler: ((_ error: Error?)->Void)?)
	func change_systemCheckpoints(checkpoint: SDcodableModel, completionHandler: ((_ error: Error?)->Void)?)

	func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?)
	func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?)

	var didStartGenerating: Bool { get set }
	func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?)

	func execute_progress(skipImageDecoding: Bool, quiet: Bool, completionHandler: ((_ error: Error?)->Void)?)
	func continueRefreshing()
	func interrupt(completionHandler: ((_ error: Error?)->Void)?)

	@MainActor func generatingAsBackgroundTask()
}


extension SDmoduleMain {
	public func synchronize_withSystem(completionHandler: ((_ error: Error?)->Void)?) {
		refresh_systemInfo {
			(error) in

			// TODO: find better evaluation for NEWly started server
			guard let folderPath = self.systemInfo?.Config?.outdir_samples else {
				DispatchQueue.main.async {
					self.generationPayload = SDcodablePayload.minimalPayload()
					completionHandler?(error)
				}
				return
			}


			self.obtain_latestPNGData(
				path: folderPath,
				completionHandler: {
					(pngData, imagePath, error) in

					guard pngData != nil
							&& imagePath != nil
					else {
						DispatchQueue.main.async {
							completionHandler?(error)
						}
						return
					}


					self.prepare_generationPayload(
						pngData: pngData!,
						imagePath: imagePath!) {
							error in

							DispatchQueue.main.async {
								if pngData != nil,
								   let latestImage = UIImage(data: pngData!) {
									self.displayedImage = latestImage
								}
								completionHandler?(error)
							}
						}
				})
		}
	}

	public func refresh_systemInfo(completionHandler: ((_ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			api_endpoint: .INTERNAL_SYSINFO) {
				(data, response, error) in
				#if DEBUG
				if let jsonDictionary = data?.jsonDictionary(quiet: true) {
					fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonDictionary)
				}
				#endif
				DispatchQueue.main.async {
					if let decodedSystemInfo = data?.decode(SDcodableSysInfo.self) {
						self.systemInfo = decodedSystemInfo
						self.use_adetailer = self.systemInfo?.extensionNames?.contains(.adetailer) ?? false
					}
					completionHandler?(error)
				}
			}
	}

	public func refresh_systemCheckpoints(completionHandler: ((_ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_MODELS) {
				(data, response, error) in
				#if DEBUG
				if let jsonObject = data?.jsonObject(quiet: true) {
					fxdPrint("MODELS", (jsonObject as? Array<Any>)?.count)
				}
				#endif
				DispatchQueue.main.async {
					if let decodedSystemCheckpoints = data?.decode(Array<SDcodableModel>.self) {
						self.systemCheckpoints = decodedSystemCheckpoints
					}
					completionHandler?(error)
				}
			}
	}

	//https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/7839
	public func change_systemCheckpoints(checkpoint: SDcodableModel, completionHandler: ((_ error: Error?)->Void)?) {
		let checkpointTitle = checkpoint.title ?? ""
		guard !(checkpointTitle.isEmpty) else {
			DispatchQueue.main.async {
				completionHandler?(nil)
			}
			return
		}


		let payload = "{\"sd_model_checkpoint\" : \"\(checkpointTitle)\"}".processedJSONData()
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_OPTIONS,
			payload: payload) {
				(data, response, error) in

				DispatchQueue.main.async {
					completionHandler?(error)
				}
			}
	}
}

extension SDmoduleMain {
	public func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			query: "folder_path=\(path)") {
				(data, response, error) in

				guard let decodedResponse = data?.decode(SDcodableFiles.self),
					  let filesORfolders = decodedResponse.files
				else {
					completionHandler?(nil, nil, error)
					return
				}

				fxdPrint("filesORfolders.count: ", filesORfolders.count)

				let latestFileORfolder = filesORfolders
					.sorted {
						($0?.updated_time)! > ($1?.updated_time)!
					}
					.filter {
						!($0?.fullpath?.contains("DS_Store") ?? false)
					}
					.first as? SDcodableFile

				fxdPrint("latestFileORfolder?.updated_time(): ", latestFileORfolder?.updated_time)
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
					self.obtain_latestPNGData(
						path: fullpath,
						completionHandler: completionHandler)
					return
				}


				self.networkingModule.requestToSDServer(
					api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
					query: "path=\(fullpath)&t=file") {
						(data, response, error) in

						completionHandler?(data, fullpath, error)
					}
			}
	}

	public func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?) {
		let _assignPayload: (String, Error?) -> Void = {
			(infotext: String, error: Error?) in

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
				self.generationPayload = obtainedPayload

				if let encodedPayload = obtainedPayload.encodedPayload() {
					SDmoduleStorage().savePayloadToFile(payload: encodedPayload)
				}

				completionHandler?(error)
			}
		}


		networkingModule.requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			query: "path=\(imagePath)",
			responseHandler: {
				(data, response, error) in

				guard let data,
					  let infotext = String(data: data, encoding: .utf8)
				else {
					_assignPayload("", error)
					return
				}

				_assignPayload(infotext, error)
			})
	}
}

extension SDmoduleMain {
	public func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		self.didStartGenerating = true
		let payload: Data? = generationPayload?.evaluatedPayload(sdEngine: self)
		
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: payload) {
				(data, response, error) in

				#if DEBUG
				if data != nil,
				   var jsonDictionary = data!.jsonDictionary() {	fxd_log()
					jsonDictionary["images"] = ["<IMAGES ENCODED>"]
					fxdPrint(dictionary: jsonDictionary)
					fxdPrint(error)
				}
				#endif


				let processedError = SDError().processsed(data, response, error)

				guard self.progressObservable?.state?.interrupted ?? false == false else {	fxd_log()
					DispatchQueue.main.async {
						self.didStartGenerating = false
						completionHandler?(processedError)
					}
					return
				}


				let decodedResponse = data?.decode(SDcodableGenerated.self)
				let encodedImageArray = decodedResponse?.images
				let pngDataArray: [Data] = encodedImageArray?.map { Data(base64Encoded: $0 ?? "") ?? Data() } ?? []
				guard pngDataArray.count > 0 else {
					DispatchQueue.main.async {
						self.didStartGenerating = false
						completionHandler?(processedError)
					}
					return
				}


				Task {
					let storage = SDmoduleStorage()

					let infotext = decodedResponse?.infotext() ?? ""
					if !(infotext.isEmpty),
					   let newlyGeneratedPayload = SDcodablePayload.decoded(infotext: infotext) {
						self.generationPayload = newlyGeneratedPayload

						if let encodedPayload = newlyGeneratedPayload.encodedPayload() {
							storage.savePayloadToFile(payload: encodedPayload)
						}
					}

					for (index, pngData) in pngDataArray.enumerated() {
						if let _ = await storage.saveGeneratedImage(pngData: pngData, index: index) {
							//self.imageURLs?.insert(latestImageURL, at: 0)
						}
					}
				}


				let newImage = UIImage(data: pngDataArray.last!)

				DispatchQueue.main.async {
					self.displayedImage = newImage

					self.didStartGenerating = false
					completionHandler?(processedError)
				}
			}
	}
}


extension SDmoduleMain {
	public func execute_progress(
		skipImageDecoding: Bool = false,
		quiet: Bool = false,
		completionHandler: ((_ error: Error?)->Void)?) {

			networkingModule.requestToSDServer(
			quiet: quiet,
			api_endpoint: .SDAPI_V1_PROGRESS) {
				(data, response, error) in

				
				DispatchQueue.main.async {
					self.progressObservable = data?.decode(SDcodableProgress.self)
					self.isSystemBusy = self.progressObservable?.state?.isJobRunning ?? false

					completionHandler?(error)
				}
			}
	}

	public func continueRefreshing() {
		if UIApplication.shared.applicationState == .background {
			fxdPrint("UIApplication.shared.backgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")
			fxdPrint("self?.networkingTaskIdentifier: ", self.networkingModule.networkingTaskIdentifier)
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				self.continueRefreshing()
			}
			return
		}

		execute_progress(
			skipImageDecoding: false,
			quiet: true,
			completionHandler: {
				(error) in

				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					self.continueRefreshing()
				}
		})
	}

	public func interrupt(completionHandler: ((_ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_INTERRUPT,
			method: "POST") {
				(data, response, error) in

				DispatchQueue.main.async {
					completionHandler?(error)
				}
			}
	}
}
