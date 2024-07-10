
import Foundation
import UIKit

import fXDKit
@preconcurrency import fxSDEngine


open class fxSDBasicEngine: NSObject, ObservableObject, @preconcurrency SDEngine, @unchecked Sendable {

	open var networkingModule: SDNetworking

	required public init(networkingModule: SDNetworking) {
		self.networkingModule = networkingModule
	}


	open var systemInfo: SDcodableSysInfo? = nil
	open var systemCheckpoints: [SDcodableModel] = []

	open var isEnabledAdetailer: Bool = false
	open var extensionADetailer: SDextensionADetailer? = {
		var adetailerExtension: SDextensionADetailer? = nil
		do {
			adetailerExtension = try JSONDecoder().decode(SDextensionADetailer.self, from: "{}".data(using: .utf8) ?? Data())
		}
		catch {	fxd_log()
			fxdPrint(error)
		}
		return adetailerExtension
	}()

	@Published open var generationPayload: SDcodablePayload? = nil

	@Published open var currentProgress: SDcodableProgress? = nil
	@Published open var isSystemBusy: Bool = false

	@Published open var displayedImage: UIImage? = nil


	public func synchronize_withSystem(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
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

	public func refresh_systemInfo(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
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

	public func refresh_systemCheckpoints(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
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

	public func change_systemCheckpoints(checkpoint: SDcodableModel, completionHandler: (@Sendable (_ error: Error?)->Void)?) {
		//https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/7839

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

	public func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: (@Sendable (_ error: Error?)->Void)?) {
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


	fileprivate var didStartGenerating: Bool = false
	open func action_Generate(payload: SDcodablePayload) {
		guard !self.didStartGenerating else {
			return
		}

		self.didStartGenerating = true

		self.execute_txt2img(payload: payload) {
			error in

			DispatchQueue.main.async {
				UIAlertController.errorAlert(error: error)

				self.didStartGenerating = false
			}
		}
	}

	public func execute_txt2img(payload: SDcodablePayload, completionHandler: (@Sendable (_ error: Error?)->Void)?) {	fxd_log()
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
					}
					completionHandler?(error)
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

	open func finish_txt2img(generated: SDcodableGenerated?, encodedImages: [String?]) async -> (newImage: UIImage?, newPayload: SDcodablePayload?)? {
		let pngDataArray: [Data] = encodedImages.map { Data(base64Encoded: $0 ?? "") ?? Data() }
		guard pngDataArray.count > 0 else {
			return nil
		}



		let infotext = generated?.infotext() ?? ""
		let extracted = self.extract_fromInfotext(infotext: infotext)
		self.extensionADetailer = extracted.1


		let newImage = UIImage(data: pngDataArray.last!)
		let newPayload: SDcodablePayload? = extracted.0

		let payloadData = newPayload.encoded()
		let storage = SDStorage()
		for (index, pngData) in pngDataArray.enumerated() {
			let (_, _) = await storage.saveGenerated(pngData: pngData, payloadData: payloadData, index: index)
		}

		return (newImage, newPayload)
	}


	public func execute_progress(quiet: Bool = false, completionHandler: (@Sendable (_ error: Error?)->Void)?) {
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

	@MainActor public func continueRefreshing() {
		if UIApplication.shared.applicationState == .background {
			fxdPrint("UIApplication.shared.backgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				self.continueRefreshing()
			}
			return
		}

		self.execute_progress(
			quiet: true,
			completionHandler: {
				(error) in

				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					self.continueRefreshing()
				}
			})
	}

	public func interrupt(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			api_endpoint: .SDAPI_V1_INTERRUPT,
			method: "POST") {
				(data, response, error) in

				DispatchQueue.main.async {
					completionHandler?(error)
				}
			}
	}


	@Published open var nonInteractiveObservable: FXDobservableOverlay? = nil

	open var action_Interrupt: () -> Void {
		return {
			self.interrupt{
				(error) in

				DispatchQueue.main.async {
					UIAlertController.errorAlert(error: error, title: "Interrupted")
				}
			}
		}
	}

	open var action_DeleteMultiple: () -> Void {
		return {
			let storage = SDStorage()
			storage.deleteFileURLs(fileURLs: storage.latestImageURLs) {
				//self.imageURLs = storage.latestImageURLs
			}
		}
	}

	open var action_DeleteOne: (_ fileURL: URL?) -> Void {
		return {
			fileURL in

			guard let fileURL else {
				return
			}

			let storage = SDStorage()
			storage.deleteFileURLs(fileURLs: [fileURL]) {
				//self.imageURLs = storage.latestImageURLs
			}
		}
	}

	open var action_SharingALL: () -> Void {
		return {
			let imageURLs = SDStorage().latestImageURLs
			if imageURLs.count > 0 {
				DispatchQueue.main.async {
					UIActivityViewController.show(items: imageURLs)
				}
			}
		}
	}

	open var action_Reload: () -> Void {
		return {
			fxd_overridable()
		}
	}

	open var action_Synchronize: () -> Void {
		return {
			fxd_overridable()
		}
	}

	open func action_ChangeCheckpoint(_ checkpoint: SDcodableModel) {
		fxd_overridable()
	}
}


