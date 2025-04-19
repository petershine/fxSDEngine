

import Foundation
import UIKit


public protocol SDEngine: Sendable {
	var mainSDNetworking: SDNetworking { get set }
    var mainSDStorage: SDStorage { get set }
    init(mainSDNetworking: SDNetworking, mainSDStorage: SDStorage)


	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableCheckpoint] { get set }
    var systemSamplers: [SDcodableSampler] { get set }
    var systemSchedulers: [SDcodableScheduler] { get set }
    var systemVAEs: [SDcodableVAE] { get set }

	var monitoredProgress: SDcodableProgress? { get set }
	var isSystemBusy: Bool { get set }
    var didStartGenerating: Bool { get set }
    var didInterrupt: Bool { get set }
    var shouldAttemptRetrieving: Bool { get set }

	var displayedImage: UIImage? { get set }

	var nextPayload: SDcodablePayload? { get set }
	var selectedImageURL: URL? { get set }


	func action_Synchronize()
    func synchronize_withSystem() async throws -> Error?
    func refresh_systemInfo() async -> Error?

    func checkpoint(for model_identifier: String?) -> SDcodableCheckpoint?
	func action_ChangeCheckpoint(_ checkpoint: SDcodableCheckpoint)
    func action_ChangeVAE(_ vae: SDcodableVAE)
    func change_systemCheckpoints(checkpoint: SDcodableCheckpoint) async -> Error?
    func change_systemVAE(vae: SDcodableVAE) async -> Error?

    func refresh_allModels() async -> Error?
    func refresh_system<T: SDprotocolModel>(_ modelType: T.Type) async -> Error?

    func obtain_latestPNGData(folderPath: String, otherFolderPath: String?) async throws -> (Data?, String?, Error?)
    func obtain_latestFilePath(folderPath: String) async throws -> (String?, Date?, Error?)
    func prepare_nextPayload(pngData: Data, imagePath: String) async throws -> (URL?, Error?)
    func extract_fromInfotext(infotext: String) -> SDcodablePayload?

	func action_Generate(payload: SDcodablePayload)
    func execute_txt2img(payload: SDcodablePayload) async throws -> Error?
    func finish_txt2img(generated: SDcodableGenerated?, utilizedControlNet: SDextensionControlNet?) async throws -> (URL?, SDcodablePayload?)

    func continueMonitoring()
    func monitor_progress(quiet: Bool) async -> (SDcodableProgress?, Bool, Error?)
    func interrupt() async -> Error?
}
