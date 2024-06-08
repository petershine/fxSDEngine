

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
	func prepare_generationPayload(imagePath: String, completionHandler: ((_ error: Error?)->Void)?)
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

	public func refresh_sysInfo(completionHandler: ((_ error: Error?)->Void)?) {
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

					if let imagePath = fullPath {
						self?.prepare_generationPayload(imagePath: imagePath, completionHandler: nil)
					}


					if pngData != nil,
					   let latestImage = UIImage(data: pngData!) {
						DispatchQueue.main.async {
							self?.observable?.displayedImage = latestImage
						}
					}
					completionHandler?(error)
				})
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

	public func prepare_generationPayload(imagePath: String, completionHandler: ((_ error: Error?)->Void)?) {
		requestToSDServer(
			api_endpoint: .INFINITE_IMAGE_BROWSING_GENINFO,
			query: "path=\(imagePath)",
			responseHandler: {
				[weak self] (received, error) in

				guard let receivedData = received,
					  let infotext = String(data: receivedData, encoding: .utf8)
				else {
					completionHandler?(error)
					return
				}


				guard let obtainedPayload = SDcodablePayload.decoded(infotext: infotext) else {
					completionHandler?(error)
					return
				}

				fxd_log()
				self?.generationPayload = obtainedPayload
				completionHandler?(error)
		})
	}
}

extension SDmoduleMain {
	public func execute_txt2img(completionHandler: ((_ error: Error?)->Void)?) {	fxd_log()
		let payload: Data? = generationPayload?.evaluatedPayload(extensions: systemInfo?.Extensions)
		requestToSDServer(
			api_endpoint: .SDAPI_V1_TXT2IMG,
			payload: payload) {
				[weak self] (data, error) in

				#if DEBUG
				if data != nil,
				   var jsonObject = data!.jsonObject() {
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


				let decodedImageArray = decodedResponse.decodedImages()

				guard let newlyGenerated = decodedImageArray.first else {
					fxdPrint("receivedData.jsonObject()\n", receivedData.jsonObject())
					completionHandler?(error)
					return
				}


				if let infotext = decodedResponse.infotext(),
				   let newlyGeneratedPayload = SDcodablePayload.decoded(infotext: infotext) {	fxd_log()
					self?.generationPayload = newlyGeneratedPayload
				}

				DispatchQueue.main.async {
					self?.observable?.displayedImage = newlyGenerated
				}
				completionHandler?(error)
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
				}
				completionHandler?(decodedResponse, error)
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
