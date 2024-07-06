

import Foundation
import UIKit

import fXDKit


public protocol SDEngine: NSObject {
	var networkingModule: SDNetworking { get set }

	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableModel] { get set }
	var generationPayload: SDcodablePayload? { get set }
	var extensionADetailer: SDextensionADetailer? { get set }

	var use_lastSeed: Bool { get set }
	var use_adetailer: Bool { get set }
	var isEnabledAdetailer: Bool { get set }

	var progressObservable: SDcodableProgress? { get set }
	var isSystemBusy: Bool { get set }

	var displayedImage: UIImage? { get set }


	func synchronize_withSystem(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_systemInfo(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_systemCheckpoints(completionHandler: ((_ error: Error?)->Void)?)
	func change_systemCheckpoints(checkpoint: SDcodableModel, completionHandler: ((_ error: Error?)->Void)?)

	func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?)
	func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?)
	func extract_fromInfotext(infotext: String) -> (SDcodablePayload?, SDextensionADetailer?)

	func execute_txt2img(payload: SDcodablePayload?, completionHandler: ((_ error: Error?)->Void)?)
	func finish_txt2img(decodedResponse: SDcodableGenerated?, pngDataArray: [Data]) async

	func execute_progress(quiet: Bool, completionHandler: ((_ error: Error?)->Void)?)
	func continueRefreshing()
	func interrupt(completionHandler: ((_ error: Error?)->Void)?)

	@MainActor func generatingAsBackgroundTask(payload: SDcodablePayload?)
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
				let payloadData = obtainedPayload.encodedPayload()
				let (_, _) = await SDStorage().saveGenerated(pngData: pngData, payloadData: payloadData, index: 0)

				//TODO: save last ADetailer


				DispatchQueue.main.async {
					fxd_log()
					self.generationPayload = obtainedPayload
					self.extensionADetailer = extracted.1

					self.use_adetailer = (self.isEnabledAdetailer && self.extensionADetailer != nil)

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

		if let sizeComponents = (payloadDictionary["size"] as? String)?.components(separatedBy: "x"),
		   sizeComponents.count == 2 {
			payloadDictionary["width"] = Int(sizeComponents.first ?? "504")
			payloadDictionary["height"] = Int(sizeComponents.last ?? "768")
		}

		let replacingKeyPairs = [
			("sampler_name", "sampler"),
			("scheduler", "schedule type"),
			("cfg_scale", "cfg scale"),

			("denoising_strength", "denoising strength"),
			("hr_scale", "hires upscale"),
			("hr_second_pass_steps", "hires steps"),
			("hr_upscaler", "hires upscaler"),
		]

		for (key, replacedKey) in replacingKeyPairs {
			payloadDictionary[key] = payloadDictionary[replacedKey]
			payloadDictionary[replacedKey] = nil
		}


		var adetailerDictionary: [String:Any?] = [:]
		let extractingKeyPairs_adetailer = [
			("ad_confidence", "adetailer confidence"),
			("ad_denoising_strength", "adetailer denoising strength"),
			("ad_dilate_erode", "adetailer dilate erode"),
			("ad_inpaint_only_masked", "adetailer inpaint only masked"),
			("ad_inpaint_only_masked_padding", "adetailer inpaint padding"),
			("ad_mask_blur", "adetailer mask blur"),
			("ad_mask_k_largest", "adetailer mask only top k largest"),
			("ad_model", "adetailer model"),
		]
		for (key, extractedKey) in extractingKeyPairs_adetailer {
			adetailerDictionary[key] = payloadDictionary[extractedKey]
			payloadDictionary[extractedKey] = nil
		}


		fxd_log()
		fxdPrint("[infotext]", infotext)
		fxdPrint(name: "payloadDictionary", dictionary: payloadDictionary)
		fxdPrint(name: "adetailerDictionary", dictionary: adetailerDictionary)

		var decodedPayload: SDcodablePayload? = nil
		do {
			let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
			decodedPayload = try JSONDecoder().decode(SDcodablePayload.self, from: payloadData)
			fxdPrint(decodedPayload!)
		}
		catch {
			fxdPrint(error)
		}

		var decodedADetailer: SDextensionADetailer? = nil
		if adetailerDictionary.count > 0 {
			do {
				let adetailerData = try JSONSerialization.data(withJSONObject: adetailerDictionary)
				decodedADetailer = try JSONDecoder().decode(SDextensionADetailer.self, from: adetailerData)
				fxdPrint(decodedADetailer!)
			}
			catch {
				fxdPrint(error)
			}
		}

		return (decodedPayload, decodedADetailer)
	}
}

extension SDEngine {
	public func execute_txt2img(payload: SDcodablePayload?, completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		var receivedPayload = payload
		var evaluatedPayload: Data? = payload?.encodedPayload()
		
		if receivedPayload == nil {
			receivedPayload = generationPayload
			evaluatedPayload = receivedPayload?.evaluatedPayload(sdEngine: self)
		}

		
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: evaluatedPayload) {
				(data, response, error) in

				#if DEBUG
				if var jsonDictionary = data?.jsonDictionary() {	fxd_log()
					jsonDictionary["images"] = ["<IMAGES ENCODED>"]
					fxdPrint(name: "TXT2IMG", dictionary: jsonDictionary)
				}
				#endif


				let decodedResponse = data?.decode(SDcodableGenerated.self)
				let encodedImageArray = decodedResponse?.images
				let pngDataArray: [Data] = encodedImageArray?.map { Data(base64Encoded: $0 ?? "") ?? Data() } ?? []
				guard pngDataArray.count > 0 else {
					DispatchQueue.main.async {
						completionHandler?(error)
					}
					return
				}


				Task {
					await self.finish_txt2img(decodedResponse: decodedResponse, pngDataArray: pngDataArray)

					DispatchQueue.main.async {
						completionHandler?(error)
					}
				}
			}
	}

	public func finish_txt2img(decodedResponse: SDcodableGenerated?, pngDataArray: [Data]) async {
		let infotext = decodedResponse?.infotext() ?? ""
		if !(infotext.isEmpty) {
			let extracted = self.extract_fromInfotext(infotext: infotext)
			if let newlyGeneratedPayload = extracted.0 {
				self.generationPayload = newlyGeneratedPayload
				self.extensionADetailer = extracted.1
			}
		}


		let storage = SDStorage()
		let payloadData = self.generationPayload?.encodedPayload()
		for (index, pngData) in pngDataArray.enumerated() {
			let (_, _) = await storage.saveGenerated(pngData: pngData, payloadData: payloadData, index: index)
		}


		let newImage = UIImage(data: pngDataArray.last!)

		DispatchQueue.main.async {
			self.displayedImage = newImage
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
