

import Foundation
import UIKit

import fXDKit


public protocol SDEngine: NSObjectProtocol {
	var networkingModule: SDNetworking { get set }
	init(networkingModule: SDNetworking)
	

	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableCheckpoint] { get set }
    var systemSamplers: [SDcodableSampler] { get set }
    var systemSchedulers: [SDcodableScheduler] { get set }
    var systemVAEs: [SDcodableVAE] { get set }

	var monitoredProgress: SDcodableProgress? { get set }
	var isSystemBusy: Bool { get set }
    var didStartGenerating: Bool { get set }
    var didInterrupt: Bool { get set }

	var displayedImage: UIImage? { get set }
    var sourceImageURL: URL? { get set }

	var nextPayload: SDcodablePayload? { get set }
	var selectedImageURL: URL? { get set }


	func action_Synchronize()
    func synchronize_withSystem() async throws -> Error?
    func refresh_systemInfo() async -> Error?

    func checkpoint(for model_hash: String?) -> SDcodableCheckpoint?
	func action_ChangeCheckpoint(_ checkpoint: SDcodableCheckpoint)
    func action_ChangeVAE(_ vae: SDcodableVAE)
    func change_systemCheckpoints(checkpoint: SDcodableCheckpoint) async -> Error?
    func change_systemVAE(vae: SDcodableVAE) async -> Error?

    func refresh_AllConfigurations() async -> Error?
    func refresh_systemCheckpoints() async -> Error?
    func refresh_systemSamplers() async -> Error?
    func refresh_systemSchedulers() async -> Error?
    func refresh_systemVAEs() async -> Error?

    func obtain_latestPNGData(path: String) async -> (Data?, String?, Error?)
    func prepare_generationPayload(pngData: Data, imagePath: String) async throws -> (URL?, Error?)
    func extract_fromInfotext(infotext: String) -> (SDcodablePayload?, SDextensionControlNet?, SDextensionADetailer?)

	func action_Generate(payload: SDcodablePayload)
    func execute_txt2img(payload: SDcodablePayload) async throws -> Error?
	func finish_txt2img(generated: SDcodableGenerated?, encodedImages: [String?]) async throws -> (URL?, SDcodablePayload?)

    func continueMonitoring()
    func monitor_progress(quiet: Bool) async -> (SDcodableProgress?, Bool, Error?)
    func interrupt() async -> Error?
}
