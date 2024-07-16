

import Foundation
import UIKit

import fXDKit


public protocol SDEngine: NSObjectProtocol {
	var networkingModule: SDNetworking { get set }
	init(networkingModule: SDNetworking)
	

	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableModel] { get set }
    var systemSamplers: [SDcodableSampler] { get set }
    var systemSchedulers: [SDcodableScheduler] { get set }

	var currentProgress: SDcodableProgress? { get set }
	var isSystemBusy: Bool { get set }

	var displayedImage: UIImage? { get set }

	var nextPayload: SDcodablePayload? { get set }
	var selectedImageURL: URL? { get set }


	func action_Synchronize()
	func synchronize_withSystem(completionHandler: (@Sendable (_ error: Error?)->Void)?)
	func refresh_systemInfo(completionHandler: (@Sendable (_ error: Error?)->Void)?)

	func action_ChangeCheckpoint(_ checkpoint: SDcodableModel)
	func refresh_systemCheckpoints(completionHandler: (@Sendable (_ error: Error?)->Void)?)
	func change_systemCheckpoints(checkpoint: SDcodableModel, completionHandler: (@Sendable (_ error: Error?)->Void)?)

    func refresh_AllConfigurations(completionHandler: (@Sendable (_ error: Error?)->Void)?)
    func refresh_systemSamplers(completionHandler: (@Sendable (_ error: Error?)->Void)?)
    func refresh_systemSchedulers(completionHandler: (@Sendable (_ error: Error?)->Void)?)

	func obtain_latestPNGData(path: String, completionHandler: (@Sendable (_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?)
	func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: (@Sendable (_ error: Error?)->Void)?)
	func extract_fromInfotext(infotext: String) -> (SDcodablePayload?, SDextensionADetailer?)

	func action_Generate(payload: SDcodablePayload)
	func execute_txt2img(payload: SDcodablePayload, completionHandler: (@Sendable (_ error: Error?)->Void)?)
	func finish_txt2img(generated: SDcodableGenerated?, encodedImages: [String?]) async -> (newImage: UIImage?, newPayload: SDcodablePayload?)?

	func execute_progress(quiet: Bool, completionHandler: (@Sendable (_ error: Error?)->Void)?)
	func continueRefreshing()
	func interrupt(completionHandler: (@Sendable (_ error: Error?)->Void)?)
}
