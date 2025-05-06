
import Foundation
import UIKit

import fXDKit


@Observable
open class fxSDengineBasic: SDEngine, @unchecked Sendable {
    public var mainNetworking: any SDNetworking
    public var mainStorage: SDStorage
    public var mainDefaultConfig: SDDefaultConfig
	required public init(mainNetworking: SDNetworking, mainStorage: SDStorage, mainDefaultConfig: SDDefaultConfig) {
        self.mainNetworking = mainNetworking
        self.mainStorage = mainStorage
        self.mainDefaultConfig = mainDefaultConfig
	}


	public var systemInfo: SDcodableSysInfo? = nil
	public var systemCheckpoints: [SDcodableCheckpoint] = []
    public var systemSamplers: [SDcodableSampler] = []
    public var systemSchedulers: [SDcodableScheduler] = []
    public var systemVAEs: [SDcodableVAE] = []
    public var systemUpscalers: [SDcodableUpscaler] = []


    public var monitoredProgress: SDcodableProgress? = nil
    public var isSystemBusy: Bool = false
    public var didStartGenerating: Bool = false {
        didSet {
            isSystemBusy = (isSystemBusy || didStartGenerating)
            if didStartGenerating == false {
                monitoredProgress = nil

                #if DEBUG
                continuousGenerating = false
                #endif
            }
        }
    }

    public var interruptedFinish: ((Error?) -> Error?)? = nil {
        didSet {
            isSystemBusy = (isSystemBusy || interruptedFinish == nil)
            shouldAttemptRecovering = false

            #if DEBUG
            continuousGenerating = false
            #endif
        }
    }

    public var shouldAttemptRecovering: Bool = false


	public var displayedImage: UIImage? = nil

    public var nextPayload: SDcodablePayload? = nil
    public var selectedImageURL: URL? = nil {
        willSet {
            if let imageURL = newValue {
                Task {	@MainActor in
                    displayedImage = UIImage(contentsOfFile: imageURL.path())
                }
            }
        }
    }


    public var controlnetImageBase64: String? = nil {
        didSet {
            nextPayload?.userConfiguration.controlnet.image = controlnetImageBase64
        }
    }

    public var lastHTTPURLResponses: [HTTPURLResponse] = []

    public var nonInteractiveObservable: FXDobservableOverlay? = nil

    #if DEBUG
    public var continuousGenerating: Bool = false
    #endif


	open func action_Synchronize() {
        Task {    @MainActor in
            nonInteractiveObservable = FXDobservableOverlay()

            let refreshError = await refresh_allModels()
            UIAlertController.errorAlert(error: refreshError)

            do {
                let synchronizeError = try await synchronize_withSystem()
                UIAlertController.errorAlert(error: synchronizeError, title: ERROR_NOT_OPERATING)
            } catch {
            }

            nonInteractiveObservable = nil
        }
	}

    public func synchronize_withSystem() async throws -> Error? {
        let error_0 = await refresh_systemInfo()

        guard error_0 == nil,
              let folderPath = systemInfo?.Config?.outdir_samples
        else {
            return error_0
        }


        let (pngData, imagePath, error_1) = try await obtain_latestPNGData(folderPath: folderPath, otherFolderPath: systemInfo?.Config?.outdir_txt2img_samples)
        guard let pngData, let imagePath else {
            return error_1
        }


        let (fileURL, error_2) = try await prepare_nextPayload(pngData: pngData, imagePath: imagePath)
        guard let fileURL else {
            return error_2
        }


        let payload = try SDcodablePayload.loaded(from: fileURL.jsonURL, withControlNet: true)
        payload?.applyDefaultConfig(remoteConfig: self.mainDefaultConfig)


        Task {	@MainActor in
            nextPayload = payload
            selectedImageURL = fileURL
        }

        return error_2
    }

    public func refresh_systemInfo() async -> Error? {
        let (data, _, error) = await mainNetworking.requestToSDServer(
			quiet: false,
            request: nil,
            reAttemptLimit: 0,
			api_endpoint: .INTERNAL_SYSINFO,
			method: nil,
			query: nil,
			payload: nil)
#if DEBUG
        if let jsonDictionary = data?.jsonDictionary(quiet: true) {
            fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonDictionary)
        }
        mainStorage.collectJSONdata(fileName: #function, jsonData: data)
#endif
        systemInfo = data?.decode(SDcodableSysInfo.self)

        return error
    }

    public func checkpoint(for model_identifier: String?) -> SDcodableCheckpoint? {
        return systemCheckpoints.filter({
            let matching_hash: Bool = ($0.hash?.isEmpty ?? true) ? false : (model_identifier ?? "").contains(($0.hash)!)
            let matching_name: Bool = ($0.model_name?.isEmpty ?? true) ? false : (model_identifier ?? "") == (($0.model_name)!)
            return (matching_hash || matching_name)
        }).first
    }

	public func action_ChangeCheckpoint(_ checkpoint: SDcodableCheckpoint) {
        Task {    @MainActor in
            nonInteractiveObservable = FXDobservableOverlay()
            defer {
                nonInteractiveObservable = nil
            }


            let error_0 = await change_systemCheckpoints(checkpoint: checkpoint)
            guard error_0 == nil else {
                UIAlertController.errorAlert(error: error_0)
                return
            }


            let error_1 = await refresh_systemInfo()
            guard error_1 == nil else {
                UIAlertController.errorAlert(error: error_1)
                return
            }


            try nextPayload?.update(with: checkpoint)

            UIAlertController.simpleAlert(
                withTitle: "APPLIED System Model for Next Image Generation",
                message: checkpoint.model_name)
        }
	}

    public func action_ChangeVAE(_ vae: SDcodableVAE) {
        Task {    @MainActor in
            nonInteractiveObservable = FXDobservableOverlay()
            defer {
                nonInteractiveObservable = nil
            }


            let error_0 = await change_systemVAE(vae: vae)

            guard error_0 == nil else {
                UIAlertController.errorAlert(error: error_0)
                return
            }


            let error_1 = await refresh_systemInfo()
            guard error_1 == nil else {
                UIAlertController.errorAlert(error: error_1)
                return
            }


            UIAlertController.simpleAlert(
                withTitle: "CHANGED System VAE for Next Image Generation",
                message: systemInfo?.Config?.sd_vae)
        }
    }

    public func change_systemCheckpoints(checkpoint: SDcodableCheckpoint) async -> Error? {
		//https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/7839

        let checkpointTitle = checkpoint.title ?? ""
		guard !(checkpointTitle.isEmpty) else {
			return nil
		}


		let options = "{\"sd_model_checkpoint\" : \"\(checkpointTitle)\"}"
        let (_, _, error) = await mainNetworking.requestToSDServer(
			quiet: false,
            request: nil,
            reAttemptLimit: 0,
			api_endpoint: .SDAPI_V1_OPTIONS,
			method: nil,
			query: nil,
            payload: options.processedJSONData())

        return error
	}

    public func change_systemVAE(vae: SDcodableVAE) async -> Error? {
        let vaeName = vae.model_name ?? ""
        guard !(vaeName.isEmpty) else {
            return nil
        }


        let modules = (vae.filename != nil) ? [vae.filename ?? ""] : []

        let options = "{\"sd_vae\" : \"\(vaeName)\", \"forge_additional_modules\" : \(modules)}"
        let (_, _, error) = await mainNetworking.requestToSDServer(
            quiet: false,
            request: nil,
            reAttemptLimit: 0,
            api_endpoint: .SDAPI_V1_OPTIONS,
            method: nil,
            query: nil,
            payload: options.processedJSONData())

        return error
    }


    public func refresh_allModels() async -> Error? {
        let error_0 = await refresh_system(SDcodableCheckpoint.self)
        guard error_0 == nil else {
            return error_0
        }

        let error_1 = await refresh_system(SDcodableSampler.self)
        guard error_1 == nil else {
            return error_1
        }

        let error_2 = await refresh_system(SDcodableScheduler.self)
        guard error_2 == nil else {
            return error_2
        }

        let error_3 = await refresh_system(SDcodableVAE.self)
        guard error_3 == nil else {
            return error_3
        }

        let error_4 = await refresh_system(SDcodableUpscaler.self)
        return error_4
    }

    public func refresh_system<T: SDprotocolModel>(_ modelType: T.Type) async -> Error? {

        var api_endpoint: SDAPIendpoint? = nil
        switch T.self {
            case is SDcodableCheckpoint.Type:
                api_endpoint = .SDAPI_V1_MODELS
            case is SDcodableVAE.Type:
                api_endpoint = .SDAPI_V1_MODULES
            case is SDcodableSampler.Type:
                api_endpoint = .SDAPI_V1_SAMPLERS
            case is SDcodableScheduler.Type:
                api_endpoint = .SDAPI_V1_SCHEDULERS
            case is SDcodableUpscaler.Type:
                api_endpoint = .SDAPI_V1_UPSCALERS

            default:
                break
        }

        guard let api_endpoint else {
            return nil
        }


        let (data, _, error) = await mainNetworking.requestToSDServer(
            quiet: false,
            request: nil,
            reAttemptLimit: 0,
            api_endpoint: api_endpoint,
            method: nil,
            query: nil,
            payload: nil)
#if DEBUG
        if let jsonObject = data?.jsonObject(quiet: true) {
            fxdPrint("\(String(describing: T.self))", (jsonObject as? Array<Any>)?.count)
        }
#endif
        let models = data?.decode(Array<T>.self) ?? []

        switch T.self {
            case is SDcodableCheckpoint.Type:
                systemCheckpoints = models as? Array<SDcodableCheckpoint> ?? []
            case is SDcodableVAE.Type:
                systemVAEs = SDcodableVAE.defaultArray() + (models as? Array<SDcodableVAE> ?? [])
            case is SDcodableSampler.Type:
                systemSamplers = models as? Array<SDcodableSampler> ?? []
            case is SDcodableScheduler.Type:
                systemSchedulers = models as? Array<SDcodableScheduler> ?? []
            case is SDcodableUpscaler.Type:
                systemUpscalers = models as? Array<SDcodableUpscaler> ?? []

            default:
                break
        }


        var refreshError: Error? = error
        switch T.self {
            case is SDcodableCheckpoint.Type:
                if systemCheckpoints.count == 0 {
                    refreshError = SDError(
                        domain: "SDEngine",
                        code: (error as? NSError)?.code ?? -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Missing models",
                            NSLocalizedFailureReasonErrorKey: "Server doesn't have any model.\nAnd once added a model, restart SD server",
                        ])
                }

            default:
                break
        }

        return refreshError
    }

    public func obtain_latestPNGData(folderPath: String, otherFolderPath: String?) async throws -> (Data?, String?, Error?) {
        let (filePath, updated_time, error) = try await obtain_latestFilePath(folderPath: folderPath)

        guard let filePath, let updated_time
        else {
            return (nil, nil, error)
        }


        var imagePath = filePath

        if let otherFolderPath {
            let (otherFilePath, otherUpdate_Time, otherError) = try await obtain_latestFilePath(folderPath: otherFolderPath)

            if otherError == nil,
               otherUpdate_Time?.compare(updated_time) == .orderedDescending,

               let otherFilePath {
                imagePath = otherFilePath
            }
        }


        let (pngData, _, obtainingError) = await mainNetworking.requestToSDServer(
            quiet: false,
            request: nil,
            reAttemptLimit: 0,
            api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
            method: nil,
            query: "path=\(imagePath.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")&t=file",
            payload: nil)

        return (pngData, imagePath, obtainingError)
    }

    public func obtain_latestFilePath(folderPath: String) async throws -> (String?, Date?, Error?) {
        let (data, response, error) = await mainNetworking.requestToSDServer(
            quiet: false,
            request: nil,
            reAttemptLimit: 0,
            api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
            method: nil,
            query: "folder_path=\(folderPath.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")",
            payload: nil)

        guard let decodedResponse = data?.decode(SDcodableFiles.self),
              let filesORfolders = decodedResponse.files
        else {
            return (nil, nil, error)
        }

        fxdPrint("response?.url", response?.url)
        fxdPrint("filesORfolders.count: ", filesORfolders.count)
        if filesORfolders.count == 0 {
            fxdPrint(data?.jsonObject())
        }

        let sortedFilesORfolders = filesORfolders
            .sorted {
                ($0?.updated_time)! > ($1?.updated_time)!
            }
            .filter {
                !($0?.fullpath?.contains("DS_Store") ?? false)
            }


        let latestFileORfolder = sortedFilesORfolders.first as? SDcodableFile
        fxdPrint("latestFileORfolder?.updated_time(): ", latestFileORfolder?.updated_time)
        fxdPrint("latestFileORfolder?.fullpath: ", latestFileORfolder?.fullpath)
        guard let latestFileORfolder,
              let filePath = latestFileORfolder.fullpath
        else {
            //TODO: error can be nil here. Prepare an error for alerting
            return (nil, nil, error)
        }


        fxdPrint("latestFileORfolder?.type: ", latestFileORfolder.type)
        guard let type = latestFileORfolder.type,
              type != "dir"
        else {
            let nextFolderPath = filePath
            return try await obtain_latestFilePath(folderPath: nextFolderPath)
        }


        let updated_time = latestFileORfolder.updated_time
        return (filePath, updated_time, error)
    }

    public func prepare_nextPayload(pngData: Data, imagePath: String) async throws -> (URL?, Error?) {
        let (data, _, error) = await mainNetworking.requestToSDServer(
			quiet: false,
            request: nil,
            reAttemptLimit: 0,
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			method: nil,
			query: "path=\(imagePath.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")",
            payload: nil)

        guard let data,
              let infotext = String(data: data, encoding: .utf8)
        else {
            return (nil, error)
        }


        guard !infotext.isEmpty, error == nil else {
            return (nil, error)
        }

        let payload = extract_fromInfotext(infotext: infotext)
        guard let payload else {
            return (nil, error)
        }


        let payloadData = payload.encoded()
        let controlnetData = payload.userConfiguration.controlnet.encoded()
        let imageURL = try await mainStorage.saveGenerated(pngData: pngData, payloadData: payloadData, controlnetData: controlnetData, index: 0)

        fxd_log()
        return (imageURL, error)
	}

    public func extract_fromInfotext(infotext: String) -> SDcodablePayload? {
		guard !(infotext.isEmpty)
				&& (infotext.contains("Steps:"))
		else {	fxd_log()
			fxdPrint("[infotext]", infotext)
			return nil
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
			return nil
		}


		let parametersString = "Steps: \(infoComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"

		var payloadDictionary: [String:Any?] = parametersString.jsonDictionary() ?? [:]
		payloadDictionary["prompt"] = prompt
		payloadDictionary["negative_prompt"] = negative_prompt


		fxd_log()
		fxdPrint("[infotext]", infotext)
		fxdPrint(name: "payloadDictionary", dictionary: payloadDictionary)
		let payload: SDcodablePayload? = SDcodablePayload.decoded(using: &payloadDictionary)
        payload?.applyDefaultConfig(remoteConfig: self.mainDefaultConfig)


        if let adetailer = SDextensionADetailer.decoded(using: &payloadDictionary) {
            payload?.userConfiguration.use_adetailer = true
            payload?.userConfiguration.adetailer = adetailer

            if payload?.userConfiguration.adetailer.ad_cfg_scale == nil {
                payload?.userConfiguration.adetailer.ad_cfg_scale = Int(payload?.cfg_scale ?? 6.0)
            }

            if payload?.userConfiguration.adetailer.ad_denoising_strength == nil {
                payload?.userConfiguration.adetailer.ad_denoising_strength = payload?.denoising_strength ?? 0.4
            }
        }

        if let controlnet = SDextensionControlNet.decoded(using: &payloadDictionary),
           !(controlnet.image?.isEmpty ?? true) {
            payload?.userConfiguration.use_controlnet = true
            payload?.userConfiguration.controlnet = controlnet
        }

        return payload
	}

	public func action_Generate(payload: SDcodablePayload) {
        guard !didStartGenerating else {
            return
        }
        
        
        didStartGenerating = true
        
        Task {	@MainActor in            
            let error = try await execute_txt2img(payload: payload)
            didStartGenerating = false
            
            UIAlertController.errorAlert(error: error)
        }
    }

	public func execute_txt2img(payload: SDcodablePayload) async throws -> Error? {	fxd_log()
		let (payloadData, utilizedControlNet) = payload.submissablePayload(mainSDEngine: self)

        let (data, urlResponse, error) = await mainNetworking.requestToSDServer(
			quiet: false,
            request: nil,
            reAttemptLimit: 0,
			api_endpoint: .SDAPI_V1_TXT2IMG,
			method: nil,
			query: nil,
			payload: payloadData)
#if DEBUG
        if var jsonDictionary = data?.jsonDictionary() {	fxd_log()
            jsonDictionary["images"] = ["<IMAGES ENCODED>"]
            fxdPrint(name: "TXT2IMG", dictionary: jsonDictionary)
        }
        mainStorage.collectJSONdata(fileName: #function, jsonData: data)
#endif
        if let httpURLResponse = urlResponse as? HTTPURLResponse {
            lastHTTPURLResponses.append(httpURLResponse)
            if lastHTTPURLResponses.count > 100 {
                lastHTTPURLResponses.removeFirst()
            }
        }

        guard error == nil else {
            var disconnectedError = error
            if interruptedFinish == nil && isSystemBusy && monitoredProgress != nil {
                shouldAttemptRecovering = true

                disconnectedError = SDError(
                    domain: "SDEngine",
                    code: (error as? NSError)?.code ?? -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Disconnected",
                        NSLocalizedFailureReasonErrorKey: "For the app is not actively opened, generated image will need to be manually recovered. Please \"synchronize\" when you re-open this app, to obtain latest image from server",
                    ])
            }

            return disconnectedError
        }


        let interrupted = self.interruptedFinish
        guard interrupted == nil else {
            self.interruptedFinish = nil
            return interrupted?(error)
        }


        let generated = data?.decode(SDcodableGenerated.self)
        guard (generated?.images?.count ?? 0) > 0 else {
            return error
        }


        let (newImageURL, newPayload) = try await finish_txt2img(
            generated: generated,
            utilizedControlNet: utilizedControlNet)

        Task {	@MainActor in
            nextPayload = newPayload
            nextPayload?.userConfiguration.controlnet = utilizedControlNet ?? SDextensionControlNet.minimum()!
            selectedImageURL = newImageURL
        }

        #if DEBUG
        if continuousGenerating {
            return try await execute_txt2img(payload: payload)
        }
        #endif

        return error
    }

    open func finish_txt2img(generated: SDcodableGenerated?, utilizedControlNet: SDextensionControlNet?) async throws -> (URL?, SDcodablePayload?) {
        guard let base64EncodedImages: [String] = generated?.images as? [String] else {
            return (nil, nil)
        }

        let decodedDataArray: [Data] = base64EncodedImages.map { Data(base64Encoded: $0) ?? Data() }
        guard decodedDataArray.count > 0 else {
            return (nil, nil)
        }


        Task {    @MainActor in
            nonInteractiveObservable = FXDobservableOverlay()
        }

        let infotext = generated?.infotext ?? ""
        let extractedPayload = extract_fromInfotext(infotext: infotext)
        if (utilizedControlNet != nil) {
            extractedPayload?.userConfiguration.use_controlnet = true
            extractedPayload?.userConfiguration.controlnet = utilizedControlNet ?? SDextensionControlNet.minimum()!
        }

        var pngDataArray = decodedDataArray
        if (extractedPayload?.userConfiguration.use_controlnet ?? false),
           let firstPNGdata = decodedDataArray.first {
            pngDataArray = [firstPNGdata]
        }

        var newImageURL: URL? = nil

        let payloadData = extractedPayload.encoded()
        let controlnetData = (extractedPayload?.userConfiguration.use_controlnet ?? false) ? utilizedControlNet?.encoded() : nil

        for (index, pngData) in pngDataArray.enumerated() {
            newImageURL = try await mainStorage.saveGenerated(pngData: pngData, payloadData: payloadData, controlnetData: controlnetData, index: index)
        }

        Task {    @MainActor in
            nonInteractiveObservable = nil
        }

		return (newImageURL, extractedPayload)
	}

    open func recover_disconnectedTxt2Img() async throws -> Error? {
        return try await synchronize_withSystem()
    }
    

    public func continueMonitoring() {
        Task {	@MainActor in
            let (newProgress, isSystemBusy, error) = await monitor_progress(quiet: true)

            if newProgress != nil || (didStartGenerating || isSystemBusy) != self.isSystemBusy {
                monitoredProgress = newProgress
                self.isSystemBusy = didStartGenerating || isSystemBusy

                if !self.isSystemBusy
                    && self.shouldAttemptRecovering {
                    self.shouldAttemptRecovering = false

                    let _ = try await recover_disconnectedTxt2Img()
                }
            }

            if error != nil,
               (error as? NSError)?.code ?? -1 == -1004 {
                fxdPrint(error)
            }

            try await Task.sleep(nanoseconds: UInt64((1.0 * 1_000_000_000).rounded()))
            continueMonitoring()
        }
    }

    public func monitor_progress(quiet: Bool) async -> (SDcodableProgress?, Bool, Error?) {
        let (data, _, error) = await mainNetworking.requestToSDServer(
            quiet: quiet,
            request: nil,
            reAttemptLimit: 0,
            api_endpoint: .SDAPI_V1_PROGRESS,
            method: nil,
            query: nil,
            payload: nil)

        let newProgress = data?.decode(SDcodableProgress.self)

        guard newProgress?.current_image != nil else {
            return (nil, false, error)
        }


        let isSystemBusy = newProgress?.state?.isSystemBusy ?? false
        return (newProgress, isSystemBusy, error)
    }


    public func interrupt() async -> Error? {
        Task {    @MainActor in
            nonInteractiveObservable = FXDobservableOverlay()
        }

        self.interruptedFinish = {
            error in

            Task {    @MainActor in
                self.nonInteractiveObservable = nil
            }


            let interruptedError = SDError(
                domain: "SDEngine",
                code: (error as? NSError)?.code ?? -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Interrupted",
                    NSLocalizedFailureReasonErrorKey: "Image generating is canceled",
                ])
            return interruptedError
        }



        let (_, _, error) = await mainNetworking.requestToSDServer(
            quiet: false,
            request: nil,
            reAttemptLimit: 0,
            api_endpoint: .SDAPI_V1_INTERRUPT,
            method: "POST",
            query: nil,
            payload: nil)

        guard !didStartGenerating else {
            return error
        }


        let interrupted = self.interruptedFinish
        self.interruptedFinish = nil

        let interruptedError = interrupted?(error)
        await UIAlertController.errorAlert(error: interruptedError)

        return interruptedError
    }
}
