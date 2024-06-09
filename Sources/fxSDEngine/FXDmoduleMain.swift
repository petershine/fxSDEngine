
import OSLog
import Foundation
import UIKit

import fXDKit


open class FXDobservableMain: NSObject, SDobservableMain {
	@Published open var overlayObservable: FXDobservableOverlay? = nil
	@Published open var progressObservable: SDcodableProgress? = nil

	@Published open var displayedImage: UIImage? = nil

	@Published open var shouldContinueRefreshing: Bool = false {
		didSet {
			if shouldContinueRefreshing == false {
				overlayObservable = nil
				progressObservable = nil
			}
		}
	}

	public init(overlayObservable: FXDobservableOverlay? = nil,
				progressObservable: SDcodableProgress? = nil,
				displayedImage: UIImage? = nil,
				shouldContinueRefreshing: Bool = false) {
		super.init()

		self.overlayObservable = overlayObservable
		self.progressObservable = progressObservable
		self.displayedImage = displayedImage
		self.shouldContinueRefreshing = shouldContinueRefreshing
	}
}


open class FXDmoduleMain: NSObject, SDmoduleMain {
	open var SD_SERVER_HOSTNAME: String {
		return "http://127.0.0.1:7860"
	}

	
	@Published open var observable: (any SDobservableMain)? = nil

	open var systemInfo: SDcodableSysInfo? = nil
	open var generationPayload: SDcodablePayload? {
		didSet {
			if let encodedPayload = generationPayload?.encodedPayload() {
				savePayloadToFile(payload: encodedPayload)
			}
		}
	}

	public init(observable: (any SDobservableMain)? = nil,
				systemInfo: SDcodableSysInfo? = nil,
				generationPayload: SDcodablePayload? = nil) {
		super.init()
		
		self.observable = observable
		self.systemInfo = systemInfo
		self.generationPayload = generationPayload
	}

	open func refresh_sysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		execute_internalSysInfo {
			[weak self] (error) in

			guard let folderPath = self?.systemInfo?.generationFolder() else {
				// TODO: find better evaluation for NEWly started server
				do {
					self?.generationPayload = try JSONDecoder().decode(SDcodablePayload.self, from: "{}".data(using: .utf8) ?? Data())
				}
				catch {
					fxdPrint(error)
				}
				completionHandler?(error)
				return
			}


			self?.obtain_latestPNGData(
				path: folderPath,
				completionHandler: {
					[weak self] (pngData, fullPath, error) in

					guard pngData != nil else {
						completionHandler?(error)
						return
					}

					guard let imagePath = fullPath else {
						completionHandler?(error)
						return
					}


					self?.prepare_generationPayload(
						pngData: pngData!,
						imagePath: imagePath) {
							error in

							if pngData != nil,
							   let latestImage = UIImage(data: pngData!) {
								DispatchQueue.main.async {
									self?.observable?.displayedImage = latestImage
								}
							}
							completionHandler?(error)
						}
				})
		}
	}

	open func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		let payload: Data? = generationPayload?.evaluatedPayload(extensions: systemInfo?.Extensions)
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: payload) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil,
				   var jsonObject = data!.jsonObject() {	fxd_log()
					jsonObject["images"] = ["<IMAGES ENCODED>"]
					fxdPrint(jsonObject)
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = SDcodableGeneration.decoded(receivedData) as? SDcodableGeneration
				else {
					completionHandler?(error)
					return
				}


				guard let encodedImage = decodedResponse.images?.first as? String else {	fxd_log()
					fxdPrint("receivedData.jsonObject()\n", receivedData.jsonObject())
					completionHandler?(error)
					return
				}


				guard let pngData = Data(base64Encoded: encodedImage) else {
					completionHandler?(error)
					return
				}



				let infotext = decodedResponse.infotext() ?? ""
				let newImage = UIImage(data: pngData)

				DispatchQueue.main.async {	fxd_log()
					if !(infotext.isEmpty),
					   let newlyGeneratedPayload = SDcodablePayload.decoded(infotext: infotext) {
						self?.generationPayload = newlyGeneratedPayload
					}

					if newImage != nil {
						self?.observable?.displayedImage = newImage
					}
					completionHandler?(error)
				}
			}
	}
}
