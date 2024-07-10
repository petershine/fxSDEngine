

import Foundation
import UIKit

import fXDKit


public protocol SDEngine: NSObjectProtocol {
	var networkingModule: SDNetworking { get set }
	init(networkingModule: SDNetworking)
	

	var systemInfo: SDcodableSysInfo? { get set }
	var systemCheckpoints: [SDcodableModel] { get set }

	var isEnabledAdetailer: Bool { get set }
	var extensionADetailer: SDextensionADetailer? { get set }

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
