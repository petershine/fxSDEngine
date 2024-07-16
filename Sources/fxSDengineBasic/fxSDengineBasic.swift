
import Foundation
import UIKit

import fXDKit


@preconcurrency open class fxSDengineBasic: NSObject, ObservableObject, SDEngine, @unchecked Sendable {

	open var networkingModule: SDNetworking

	required public init(networkingModule: SDNetworking) {
		self.networkingModule = networkingModule
	}


	open var systemInfo: SDcodableSysInfo? = nil
	open var systemCheckpoints: [SDcodableModel] = []
    open var systemSamplers: [SDcodableSampler] = []
    open var systemSchedulers: [SDcodableScheduler] = []


	@Published open var currentProgress: SDcodableProgress? = nil
	@Published open var isSystemBusy: Bool = false

	@Published open var displayedImage: UIImage? = nil

	@Published open var nextPayload: SDcodablePayload? = nil
	@Published open var selectedImageURL: URL? {
		didSet {
			guard let jsonURL = selectedImageURL?.jsonURL else {
				return
			}

			do {
				let payloadData = try Data(contentsOf: jsonURL)
				nextPayload = payloadData.decode(SDcodablePayload.self)
			}
			catch {	fxd_log()
				fxdPrint(error)
			}
		}
	}

    @Published open var nonInteractiveObservable: FXDobservableOverlay? = nil


	open func action_Synchronize() {
		self.synchronize_withSystem {
			(error) in

            self.refresh_AllConfigurations(completionHandler: nil)

			DispatchQueue.main.async {
				UIAlertController.errorAlert(error: error, title: "Possibly, your Stable Diffusion server is not operating.")
			}
		}
	}

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
			quiet: false,
			api_endpoint: .INTERNAL_SYSINFO,
			method: nil,
			query: nil,
			payload: nil) {
				(data, response, error) in
#if DEBUG
				if let jsonDictionary = data?.jsonDictionary(quiet: true) {
					fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonDictionary)
				}
#endif
				DispatchQueue.main.async {
					self.systemInfo = data?.decode(SDcodableSysInfo.self)
					completionHandler?(error)
				}
			}
	}


	open func action_ChangeCheckpoint(_ checkpoint: SDcodableModel) {
		self.change_systemCheckpoints(checkpoint: checkpoint) {
			error in

			guard error == nil else {
				DispatchQueue.main.async {
					UIAlertController.errorAlert(error: error)
				}
				return
			}


			self.refresh_systemInfo {
				(error) in

				DispatchQueue.main.async {
					UIAlertController.errorAlert(error: error)
				}
			}
		}
	}

	public func refresh_systemCheckpoints(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .SDAPI_V1_MODELS,
			method: nil,
			query: nil,
			payload: nil) {
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
			quiet: false,
			api_endpoint: .SDAPI_V1_OPTIONS,
			method: nil,
			query: nil,
			payload: overridePayload) {
				(data, response, error) in

				DispatchQueue.main.async {
					completionHandler?(error)
				}
			}
	}


    public func refresh_AllConfigurations(completionHandler: (@Sendable (_ error: Error?)->Void)?) {

        self.refresh_systemCheckpoints {
            error in

            self.refresh_systemSamplers {
                error in

                self.refresh_systemSchedulers {
                    error in

                    DispatchQueue.main.async {
                        completionHandler?(error)
                    }
                }
            }
        }
    }
    
    public func refresh_systemSamplers(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
        networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_SAMPLERS,
            method: nil,
            query: nil,
            payload: nil) {
                (data, response, error) in
#if DEBUG
                if let jsonObject = data?.jsonObject(quiet: true) {
                    fxdPrint("SAMPLERS", (jsonObject as? Array<Any>)?.count)
                }
#endif
                DispatchQueue.main.async {
                    self.systemSamplers = data?.decode(Array<SDcodableSampler>.self) ?? []
                    completionHandler?(error)
                }
            }
    }

    public func refresh_systemSchedulers(completionHandler: (@Sendable (_ error: Error?)->Void)?) {
        networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_SCHEDULERS,
            method: nil,
            query: nil,
            payload: nil) {
                (data, response, error) in
#if DEBUG
                if let jsonObject = data?.jsonObject(quiet: true) {
                    fxdPrint("SCHEDULERS", (jsonObject as? Array<Any>)?.count)
                }
#endif
                DispatchQueue.main.async {
                    self.systemSchedulers = data?.decode(Array<SDcodableScheduler>.self) ?? []
                    completionHandler?(error)
                }
            }
    }


	public func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?) {
		networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			method: nil,
			query: "folder_path=\(path)",
			payload: nil) {
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
					quiet: false,
					api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
					method: nil,
					query: "path=\(fullpath)&t=file",
					payload: nil) {
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
			guard let payload = extracted.0 else {
				completionHandler?(error)
				return
			}


			Task {
				let payloadData = payload.encoded()
				let (_, _) = await SDStorage().saveGenerated(pngData: pngData, payloadData: payloadData, index: 0)


				await MainActor.run {
					fxd_log()
					completionHandler?(error)
				}
			}
		}


		networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			method: nil,
			query: "path=\(imagePath)",
			payload: nil) {
				(data, response, error) in

				guard let data,
					  let infotext = String(data: data, encoding: .utf8)
				else {
					_assignPayload("", error)
					return
				}

				_assignPayload(infotext, error)
			}
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


	open func action_Generate(payload: SDcodablePayload) {
		self.execute_txt2img(payload: payload) {
			error in

			DispatchQueue.main.async {
				UIAlertController.errorAlert(error: error)
			}
		}
	}

	public func execute_txt2img(payload: SDcodablePayload, completionHandler: (@Sendable (_ error: Error?)->Void)?) {	fxd_log()
		let payloadData: Data? = payload.extendedPayload(sdEngine: self)

		networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .SDAPI_V1_TXT2IMG,
			method: nil,
			query: nil,
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
//						self.generationPayload = newlyGenerated?.1
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
//		self.extensionADetailer = extracted.1


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
			api_endpoint: .SDAPI_V1_PROGRESS,
			method: nil,
			query: nil,
			payload: nil) {
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
			quiet: false,
			api_endpoint: .SDAPI_V1_INTERRUPT,
			method: "POST",
			query: nil,
			payload: nil) {
				(data, response, error) in

				DispatchQueue.main.async {
					completionHandler?(error)
				}
			}
	}
}


