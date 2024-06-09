

import Foundation
import UIKit

import fXDKit


public protocol SDobservableMain: ObservableObject {
	var overlayObservable: FXDobservableOverlay? { get set }
	var progressObservable: SDcodableProgress? { get set }

	var displayedImage: UIImage? { get set }

	var shouldContinueRefreshing: Bool { get set }
}

public protocol SDmoduleMain: NSObject, SDnetworking {
	var observable: (any SDobservableMain)? { get set }

	var systemInfo: SDcodableSysInfo? { get set }
	var generationPayload: SDcodablePayload? { get set }


	func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?)
	func refresh_sysInfo(completionHandler: ((_ error: Error?)->Void)?)

	func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?)
	func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?)
	func extract_infotext(pngData: Data) async -> String

	func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?)

	func execute_progress(skipImageDecoding: Bool, quiet: Bool, completionHandler: ((_ lastProgress: SDcodableProgress?, _ error: Error?)->Void)?)
	func continuousProgressRefreshing()
	func interrupt(completionHandler: ((_ error: Error?)->Void)?)
}


extension SDmoduleMain {
	public func execute_internalSysInfo(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INTERNAL_SYSINFO) {
				[weak self] (data, error) in

				#if DEBUG
				if let jsonObject = data?.jsonObject(quiet: true) {
					fxdPrint(name: "INTERNAL_SYSINFO", dictionary: jsonObject)
				}
				#endif

				guard let receivedData = data,
					  let decodedResponse = SDcodableSysInfo.decoded(receivedData) as? SDcodableSysInfo
				else {
					completionHandler?(error)
					return
				}

				self?.systemInfo = decodedResponse
				completionHandler?(error)
			}
	}
}

extension SDmoduleMain {
	public func obtain_latestPNGData(path: String, completionHandler: ((_ pngData: Data?, _ path: String?, _ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_FILES,
			query: "folder_path=\(path)") {
				[weak self] (data, error) in

				guard let receivedData = data,
					  let decodedResponse = SDcodableFiles.decoded(receivedData) as? SDcodableFiles,
					  let filesORfolders = decodedResponse.files
				else {
					completionHandler?(nil, nil, error)
					return
				}

				fxdPrint("filesORfolders.count: ", filesORfolders.count)

				let latestFileORfolder = filesORfolders
					.sorted {
						($0?.updated_time())! > ($1?.updated_time())!
					}
					.filter {
						!($0?.fullpath?.contains("DS_Store") ?? false)
					}
					.first as? SDcodableFile

				fxdPrint("latestFileORfolder?.updated_time(): ", latestFileORfolder?.updated_time())
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
					self?.obtain_latestPNGData(
						path: fullpath,
						completionHandler: completionHandler)
					return
				}


				self?.requestToSDServer(
					api_endpoint: .INFINITE_IMAGE_BROWSING_FILE,
					query: "path=\(fullpath)&t=file") {
						(received, error) in

						guard let pngData = received else {
							completionHandler?(nil, fullpath, error)
							return
						}


						completionHandler?(pngData, fullpath, error)
					}
			}
	}

	public func prepare_generationPayload(pngData: Data, imagePath: String, completionHandler: ((_ error: Error?)->Void)?) {
		Task {	@MainActor
			[weak self] in

			let _assignPayload: (String, Error?) -> Void = {
				[weak self] (infotext: String, error: Error?) in

				guard !infotext.isEmpty, error == nil else {
					completionHandler?(error)
					return
				}

				guard let obtainedPayload = SDcodablePayload.decoded(infotext: infotext) else {
					completionHandler?(error)
					return
				}

				DispatchQueue.main.async {
					fxd_log()
					self?.generationPayload = obtainedPayload
					completionHandler?(error)
				}
			}


			let infotext = await self?.extract_infotext(pngData: pngData) ?? ""
			if !(infotext.isEmpty) {
				_assignPayload(infotext, nil)
				return
			}


			self?.requestToSDServer(
				api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
				query: "path=\(imagePath)",
				responseHandler: {
					(received, error) in

					guard let receivedData = received,
						  let infotext = String(data: receivedData, encoding: .utf8)
					else {
						_assignPayload("", error)
						return
					}

					_assignPayload(infotext, error)
				})
		}
	}
}


extension SDmoduleMain {
	public func execute_progress(skipImageDecoding: Bool, quiet: Bool = false, completionHandler: ((_ lastProgress: SDcodableProgress?, _ error: Error?)->Void)?) {
		requestToSDServer(
			quiet: quiet,
			api_endpoint: .SDAPI_V1_PROGRESS) {
				[weak self] (data, error) in

				guard let receivedData = data,
					  let decodedResponse = SDcodableProgress.decoded(receivedData) as? SDcodableProgress
				else {
					completionHandler?(nil, error)
					return
				}


				var progressImage: UIImage? = nil
				if !skipImageDecoding,
				   let imageEncoded = decodedResponse.current_image,
				   let decodedImage = imageEncoded.decodedImage() {
					progressImage = decodedImage
				}


				DispatchQueue.main.async {
					if progressImage != nil {
						self?.observable?.displayedImage = progressImage
					}

					self?.observable?.progressObservable = decodedResponse
					completionHandler?(decodedResponse, error)
				}
			}
	}

	public func continuousProgressRefreshing() {
		guard observable?.shouldContinueRefreshing ?? false else {
			return
		}


		execute_progress(
			skipImageDecoding: false,
			quiet: true,
			completionHandler: {
				[weak self] (lastProgress, error) in

				self?.continuousProgressRefreshing()
		})
	}

	public func interrupt(completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .SDAPI_V1_INTERRUPT,
			method: "POST") {
				[weak self] (receivedData, error) in

				self?.execute_progress(
					skipImageDecoding: true,
					quiet: true,
					completionHandler: {
						lastProgress, error in

						fxdPrint("[lastProgress?.state]: ", lastProgress?.state)
						completionHandler?(error)
					})
			}
	}
}
