

import Foundation
import UIKit

import fXDKit


public protocol SDEngine: NSObject {
	var networkingModule: SDNetworking { get set }

	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableModel] { get set }
	var extensionADetailer: SDextensionADetailer? { get set }
	var isEnabledAdetailer: Bool { get set }
	
	var generationPayload: SDcodablePayload? { get set }

	var currentProgress: SDcodableProgress? { get set }
	var isSystemBusy: Bool { get set }

	var displayedImage: UIImage? { get set }


	func synchronize_withSystem(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_systemInfo(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_systemCheckpoints(completionHandler: ((_ error: Error?)->Void)?)
	func change_systemCheckpoints(checkpoint: SDcodableModel, completionHandler: ((_ error: Error?)->Void)?)

	func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?)
	func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?)
	func extract_fromInfotext(infotext: String) -> (SDcodablePayload?, SDextensionADetailer?)

	func action_Generate(payload: SDcodablePayload)
	func execute_txt2img(payload: SDcodablePayload, completionHandler: ((_ error: Error?)->Void)?)
	func finish_txt2img(generated: SDcodableGenerated?, encodedImages: [String?]) async -> (newImage: UIImage?, newPayload: SDcodablePayload?)?

	func execute_progress(quiet: Bool, completionHandler: ((_ error: Error?)->Void)?)
	func continueRefreshing()
	func interrupt(completionHandler: ((_ error: Error?)->Void)?)
}


extension SDEngine {
	public func synchronize_withSystem(completionHandler: ((_ error: Error?)->Void)?) {
		refresh_systemInfo {
			(error) in

			// TODO: find better evaluation for NEWly started server
			guard let folderPath = self.systemInfo?.Config?.outdir_samples else {
				DispatchQueue.main.async {
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
					self.systemInfo = data?.decode(SDcodableSysInfo.self)
					self.isEnabledAdetailer = self.systemInfo?.extensionNames?.contains(.adetailer) ?? false
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
					self.systemCheckpoints = data?.decode(Array<SDcodableModel>.self) ?? []
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


		let overridePayload = "{\"sd_model_checkpoint\" : \"\(checkpointTitle)\"}".processedJSONData()
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_OPTIONS,
			payload: overridePayload) {
				(data, response, error) in

				DispatchQueue.main.async {
					completionHandler?(error)
				}
			}
	}
}

extension SDEngine {
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

			let extracted = self.extract_fromInfotext(infotext: infotext)
			guard let obtainedPayload = extracted.0 else {
				completionHandler?(error)
				return
			}


			Task {
				let payloadData = obtainedPayload.encoded()
				let (_, _) = await SDStorage().saveGenerated(pngData: pngData, payloadData: payloadData, index: 0)

				//TODO: save last ADetailer, assign use_adetailer


				DispatchQueue.main.async {
					fxd_log()
					self.generationPayload = obtainedPayload
					self.extensionADetailer = extracted.1

					completionHandler?(error)
				}
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

	public func extract_fromInfotext(infotext: String) -> (SDcodablePayload?, SDextensionADetailer?) {
		guard !(infotext.isEmpty)
				&& (infotext.contains("Steps:"))
		else {	fxd_log()
			fxdPrint("[infotext]", infotext)
			return (nil, nil)
		}


		let infoComponents = infotext.lineReBroken().components(separatedBy: "Steps:")
		let promptPair = infoComponents.first?.components(separatedBy: "Negative prompt:")

		var prompt = promptPair?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if prompt.first == "\"" {
			prompt.removeFirst()
		}

		let negative_prompt = promptPair?.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

		guard !(prompt.isEmpty) else {	fxd_log()
			fxdPrint("[infotext]", infotext)
			return (nil, nil)
		}


		let parametersString = "Steps: \(infoComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"

		var payloadDictionary: [String:Any?] = parametersString.jsonDictionary() ?? [:]
		payloadDictionary["prompt"] = prompt
		payloadDictionary["negative_prompt"] = negative_prompt


		fxd_log()
		fxdPrint("[infotext]", infotext)
		fxdPrint(name: "payloadDictionary", dictionary: payloadDictionary)
		let decodedPayload: SDcodablePayload? = SDcodablePayload.decoded(using: &payloadDictionary)
		let decodedADetailer: SDextensionADetailer? = SDextensionADetailer.decoded(using: &payloadDictionary)

		return (decodedPayload, decodedADetailer)
	}
}

extension SDEngine {
	public func execute_txt2img(payload: SDcodablePayload, completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		let payloadData: Data? = payload.extendedPayload(sdEngine: self)

		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: payloadData) {
				(data, response, error) in

				#if DEBUG
				if var jsonDictionary = data?.jsonDictionary() {	fxd_log()
					jsonDictionary["images"] = ["<IMAGES ENCODED>"]
					fxdPrint(name: "TXT2IMG", dictionary: jsonDictionary)
				}
				#endif


				let generated = data?.decode(SDcodableGenerated.self)
				let encodedImages = generated?.images ?? []
				guard encodedImages.count > 0 else {
					DispatchQueue.main.async {
						completionHandler?(error)
					}
					return
				}


				Task {
					let newlyGenerated = await self.finish_txt2img(
						generated: generated,
						encodedImages: encodedImages)
					
					await MainActor.run {
						self.displayedImage = newlyGenerated?.0
						self.generationPayload = newlyGenerated?.1
						completionHandler?(error)
					}
				}
			}
	}
}


extension SDEngine {
	public func execute_progress(
		quiet: Bool = false,
		completionHandler: ((_ error: Error?)->Void)?) {

			networkingModule.requestToSDServer(
			quiet: quiet,
			api_endpoint: .SDAPI_V1_PROGRESS) {
				(data, response, error) in

				
				DispatchQueue.main.async {
					self.currentProgress = data?.decode(SDcodableProgress.self)

					let isJobRunning = self.currentProgress?.state?.isJobRunning ?? false
					if self.isSystemBusy != isJobRunning {
						self.isSystemBusy = isJobRunning
					}

					completionHandler?(error)
				}
			}
	}

	public func continueRefreshing() {
		if UIApplication.shared.applicationState == .background {
			fxdPrint("UIApplication.shared.backgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				self.continueRefreshing()
			}
			return
		}

		execute_progress(
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
