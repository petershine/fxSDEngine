
import Foundation
import UIKit

import fXDKit


@preconcurrency open class fxSDengineBasic: NSObject, ObservableObject, @unchecked Sendable, SDEngine {

	open var networkingModule: SDNetworking

	required public init(networkingModule: SDNetworking) {
        self.networkingModule = networkingModule
	}


	open var systemInfo: SDcodableSysInfo? = nil
	open var systemCheckpoints: [SDcodableCheckpoint] = []
    open var systemSamplers: [SDcodableSampler] = []
    open var systemSchedulers: [SDcodableScheduler] = []
    open var systemVAEs: [SDcodableVAE] = []


	@Published open var currentProgress: SDcodableProgress? = nil
	@Published open var isSystemBusy: Bool = false

	@Published open var displayedImage: UIImage? = nil

	@Published open var nextPayload: SDcodablePayload? = nil
    @Published open var selectedImageURL: URL? {
        willSet {
            if let imageURL = newValue {
                Task {	@MainActor in
                    let loadedImage = UIImage(contentsOfFile: imageURL.path())

                    displayedImage = loadedImage
                }
            }
        }
    }

    @Published open var nonInteractiveObservable: FXDobservableOverlay? = nil


	open func action_Synchronize() {
        Task {	@MainActor in
            let error = try await synchronize_withSystem()
            let _ = await refresh_AllConfigurations()

            UIAlertController.errorAlert(error: error, title: "Possibly, your Stable Diffusion server is not operating.")
        }
	}

    public func synchronize_withSystem() async throws -> Error? {
        let error_0 = await refresh_systemInfo()

        // TODO: find better evaluation for newly started server
        guard let folderPath = systemInfo?.Config?.outdir_samples else {
            return error_0
        }


        let obtained = await obtain_latestPNGData(path: folderPath)

        let pngData = obtained?.0
        let imagePath = obtained?.1
        let error_1 = obtained?.2

        guard pngData != nil
                && imagePath != nil
        else {
            return error_1
        }


        let prepared = try await prepare_generationPayload(pngData: pngData!, imagePath: imagePath!)

        let imageURL = prepared?.0
        let error_2 = prepared?.1

        let loadedPayload = try SDcodablePayload.loaded(from: imageURL)

        await MainActor.run {
            nextPayload = loadedPayload
            selectedImageURL = imageURL
        }

        return error_2
    }

    public func refresh_systemInfo() async -> Error? {
        let completion = await networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .INTERNAL_SYSINFO,
			method: nil,
			query: nil,
			payload: nil)

        let data = completion?.0
        let _  = completion?.1
        let error = completion?.2
#if DEBUG
        if let jsonDictionary = data?.jsonDictionary(quiet: true) {
            fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonDictionary)
        }
#endif
        await MainActor.run {
            systemInfo = data?.decode(SDcodableSysInfo.self)
        }

        return error
    }

    open func checkpoint(for model_hash: String?) -> SDcodableCheckpoint? {
        return systemCheckpoints.filter({
            return ($0.hash?.isEmpty ?? true) ? false : (model_hash ?? "").contains(($0.hash)!)
        }).first
    }

	open func action_ChangeCheckpoint(_ checkpoint: SDcodableCheckpoint) {
        Task {
            let error_0 = await change_systemCheckpoints(checkpoint: checkpoint)

			guard error_0 == nil else {
				DispatchQueue.main.async {
					UIAlertController.errorAlert(error: error_0)
				}
				return
			}


            let error_1 = await refresh_systemInfo()

            DispatchQueue.main.async {
                UIAlertController.errorAlert(error: error_1)
            }
        }
	}

    public func change_systemCheckpoints(checkpoint: SDcodableCheckpoint) async -> Error? {
		//https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/7839

		let checkpointTitle = checkpoint.title ?? ""
		guard !(checkpointTitle.isEmpty) else {
			return nil
		}


		let optionsPayload = "{\"sd_model_checkpoint\" : \"\(checkpointTitle)\"}".processedJSONData()
        let completion = await networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .SDAPI_V1_OPTIONS,
			method: nil,
			query: nil,
			payload: optionsPayload)

        let _ = completion?.0
        let _  = completion?.1
        let error = completion?.2

        return error
	}

    public func change_systemVAE(vae: SDcodableVAE) async -> Error? {
        let vaeName = vae.model_name ?? ""
        guard !(vaeName.isEmpty) else {
            return nil
        }


        let optionsPayload = "{\"sd_vae\" : \"\(vaeName)\"}".processedJSONData()
        let completion = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_OPTIONS,
            method: nil,
            query: nil,
            payload: optionsPayload)
        
        let _ = completion?.0
        let _  = completion?.1
        let error = completion?.2

        return error
    }


    public func refresh_AllConfigurations() async -> Error? {
        let error_0 = await refresh_systemCheckpoints()
        guard error_0 == nil else {
            return error_0
        }

        let error_1 = await refresh_systemSamplers()
        guard error_1 == nil else {
            return error_1
        }

        let error_2 = await refresh_systemSchedulers()
        guard error_2 == nil else {
            return error_2
        }

        let error_3 = await refresh_systemVAEs()
        return error_3
    }

    public func refresh_systemCheckpoints() async -> Error? {
        let completion = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_MODELS,
            method: nil,
            query: nil,
            payload: nil)

        let data = completion?.0
        let _  = completion?.1
        let error = completion?.2
#if DEBUG
        if let jsonObject = data?.jsonObject(quiet: true) {
            fxdPrint("MODELS", (jsonObject as? Array<Any>)?.count)
        }
#endif
        await MainActor.run {
            systemCheckpoints = data?.decode(Array<SDcodableCheckpoint>.self) ?? []
        }

        return error
    }

    public func refresh_systemSamplers() async -> Error? {
        let completion = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_SAMPLERS,
            method: nil,
            query: nil,
            payload: nil)

        let data = completion?.0
        let _  = completion?.1
        let error = completion?.2
#if DEBUG
        if let jsonObject = data?.jsonObject(quiet: true) {
            fxdPrint("SAMPLERS", (jsonObject as? Array<Any>)?.count)
        }
#endif
        await MainActor.run {
            systemSamplers = data?.decode(Array<SDcodableSampler>.self) ?? []
        }

        return error
    }

    public func refresh_systemSchedulers() async -> Error? {
        let completion = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_SCHEDULERS,
            method: nil,
            query: nil,
            payload: nil)

        let data = completion?.0
        let _  = completion?.1
        let error = completion?.2
#if DEBUG
        if let jsonObject = data?.jsonObject(quiet: true) {
            fxdPrint("SCHEDULERS", (jsonObject as? Array<Any>)?.count)
        }
#endif
        await MainActor.run {
            systemSchedulers = data?.decode(Array<SDcodableScheduler>.self) ?? []
        }

        return error
    }

    public func refresh_systemVAEs() async -> Error? {
        let completion = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_VAE,
            method: nil,
            query: nil,
            payload: nil)

        let data = completion?.0
        let _  = completion?.1
        let error = completion?.2
#if DEBUG
        if let jsonObject = data?.jsonObject(quiet: true) {
            fxdPrint("VAEs", (jsonObject as? Array<Any>)?.count)
        }
#endif
        await MainActor.run {
            var defaultVAEs = SDcodableVAE.defaultArray()
            defaultVAEs += data?.decode(Array<SDcodableVAE>.self) ?? []
            systemVAEs = defaultVAEs
        }

        return error
    }

    public func obtain_latestPNGData(path: String) async -> (Data?, String?, Error?)? {
        let completion = await networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			method: nil,
			query: "folder_path=\(path)",
			payload: nil)

        let data = completion?.0
        let _  = completion?.1
        let error = completion?.2


        guard let decodedResponse = data?.decode(SDcodableFiles.self),
              let filesORfolders = decodedResponse.files
        else {
            return (nil, nil, error)
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
            //TODO: error can be nil here. Prepare an error for alerting
            return (nil, nil, error)
        }


        fxdPrint("latestFileORfolder?.type: ", latestFileORfolder?.type)
        guard let type = latestFileORfolder?.type,
              type != "dir"
        else {
            //recursive
            return await obtain_latestPNGData(path: fullpath)
        }


        let obtained = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
            method: nil,
            query: "path=\(fullpath)&t=file",
            payload: nil)

        return (obtained?.0, fullpath, obtained?.2)
    }

    public func prepare_generationPayload(pngData: Data, imagePath: String) async throws -> (URL?, Error?)? {
        let completion = await networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			method: nil,
			query: "path=\(imagePath)",
			payload: nil)

        let data = completion?.0
        let _ = completion?.1
        let error = completion?.2

        guard let data,
              let infotext = String(data: data, encoding: .utf8)
        else {
            return (nil, error)
        }


        guard !infotext.isEmpty, error == nil else {
            return (nil, error)
        }

        let extracted = extract_fromInfotext(infotext: infotext)
        guard let payload = extracted.0 else {
            return (nil, error)
        }


        let payloadData = payload.encoded()
        let imageURL = try await SDStorage().saveGenerated(pngData: pngData, payloadData: payloadData, index: 0)

        fxd_log()
        return (imageURL, error)
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

		var negative_prompt = promptPair?.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if promptPair?.count ?? 0 < 2 || negative_prompt == prompt {
            negative_prompt = ""
        }

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

        if decodedADetailer != nil {
            decodedPayload?.use_adetailer = true
        }

		return (decodedPayload, decodedADetailer)
	}

    open var didStartGenerating: Bool = false {
        didSet {
            if didStartGenerating {
                continueRefreshing()
            }
            else {
                currentProgress = nil
                isSystemBusy = false
            }
        }
    }

	open func action_Generate(payload: SDcodablePayload) {
        guard !didStartGenerating else {
            return
        }


        didStartGenerating = true

        Task {    @MainActor in
            let error = try await execute_txt2img(payload: payload)
            UIAlertController.errorAlert(error: error)

            didStartGenerating = false
        }
    }

	public func execute_txt2img(payload: SDcodablePayload) async throws -> Error? {	fxd_log()
		let payloadData: Data? = payload.submissablePayload(sdEngine: self)

        let completion = await networkingModule.requestToSDServer(
			quiet: false,
			api_endpoint: .SDAPI_V1_TXT2IMG,
			method: nil,
			query: nil,
			payload: payloadData)

        let data = completion?.0
        let _ = completion?.1
        let error = completion?.2

#if DEBUG
        if var jsonDictionary = data?.jsonDictionary() {	fxd_log()
            jsonDictionary["images"] = ["<IMAGES ENCODED>"]
            fxdPrint(name: "TXT2IMG", dictionary: jsonDictionary)
        }
#endif


        let generated = data?.decode(SDcodableGenerated.self)
        let encodedImages = generated?.images ?? []
        guard encodedImages.count > 0 else {
            return error
        }


        let newlyGenerated = try await finish_txt2img(
            generated: generated,
            encodedImages: encodedImages)


        await MainActor.run {
            nextPayload = newlyGenerated?.newPayload
            selectedImageURL = newlyGenerated?.newImageURL
        }

        return error
    }

	open func finish_txt2img(generated: SDcodableGenerated?, encodedImages: [String?]) async throws -> (newImageURL: URL?, newPayload: SDcodablePayload?)? {
		let pngDataArray: [Data] = encodedImages.map { Data(base64Encoded: $0 ?? "") ?? Data() }
		guard pngDataArray.count > 0 else {
			return nil
		}


		let infotext = generated?.infotext ?? ""
		let extracted = extract_fromInfotext(infotext: infotext)

		let newPayload: SDcodablePayload? = extracted.0
		let payloadData = newPayload.encoded()

        var newImageURL: URL? = nil
        let storage = SDStorage()
		for (index, pngData) in pngDataArray.enumerated() {
            newImageURL = try await storage.saveGenerated(pngData: pngData, payloadData: payloadData, index: index)
		}

		return (newImageURL, newPayload)
	}


    open func continueRefreshing() {
        if !didStartGenerating {
            return
        }

        Task {
            let _ = await execute_progress(quiet: true)
            try await Task.sleep(nanoseconds: UInt64((1.0 * 1_000_000_000).rounded()))

            continueRefreshing()
        }
    }

    public func execute_progress(quiet: Bool = false) async -> Error? {
        let completion = await networkingModule.requestToSDServer(
            quiet: quiet,
            api_endpoint: .SDAPI_V1_PROGRESS,
            method: nil,
            query: nil,
            payload: nil)

        let data = completion?.0
        let error = completion?.2

        let newProgress = data?.decode(SDcodableProgress.self)
        let isJobRunning = newProgress?.state?.isJobRunning ?? false

        
        await MainActor.run {
            currentProgress = newProgress

            if isSystemBusy != isJobRunning {
                isSystemBusy = isJobRunning
            }
        }

        return error
    }


    @MainActor public func interrupt() async -> Error? {
        let completion = await networkingModule.requestToSDServer(
            quiet: false,
            api_endpoint: .SDAPI_V1_INTERRUPT,
            method: "POST",
            query: nil,
            payload: nil)

        let error = completion?.2

        return error
    }
}


