
import Foundation
import UIKit

import fXDKit
import UniformTypeIdentifiers


open class SDStorage: NSObject, ObservableObject {
	@Published open var latestImageURLs: [URL] = {
		return FileManager.default.fileURLs(contentType: .png) ?? []
	}()

	public var latestJsonURLs: [URL]? {
		return FileManager.default.fileURLs(contentType: .json)
	}


	public override init() {
		super.init()
	}
}

extension SDStorage {
	fileprivate func newFileURL(index: Int, contentType: UTType) -> URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"

		let fileName = dateFormatter.string(from: Date.now)
		let fileURL = documentDirectory?.appendingPathComponent("GenerArt_\(fileName)_\(index).\(contentType.preferredFilenameExtension ?? contentType.identifier.components(separatedBy: ".").last ?? "png")")
		return fileURL
	}

	func saveGenerated(pngData: Data, payloadData: Data?, index: Int = 0) async -> (imageURL: URL?, payloadURL: URL?) {
		guard let imageURL = newFileURL(index: index, contentType: UTType.png) else {
			return (nil, nil)
		}


		fxd_log()
		do {
			fxdPrint("pngData: ", pngData)
			try pngData.write(to: imageURL)
			fxdPrint("[IMAGE FILE SAVED]: ", imageURL)


			fxdPrint("payloadData: ", payloadData)
			try payloadData?.write(to: imageURL.jsonURL)
			fxdPrint("[PAYLOAD JSON SAVED]: ", imageURL.jsonURL)

			return (imageURL, imageURL.jsonURL)

		} catch {
			fxdPrint(error)
			return (nil, nil)
		}
	}
}

extension SDStorage {
	public func deleteFileURLs(fileURLs: [URL], completionHandler: (() -> Void)?) {
		guard fileURLs.count > 0 else {
			completionHandler?()
			return
		}


		let message: String = (fileURLs.count > 1) ? "\(fileURLs.count) images" : (fileURLs.first?.absoluteURL.lastPathComponent ?? "")

		UIAlertController.simpleAlert(
			withTitle: "Do you want to delete?",
			message: message,
			destructiveText: "DELETE",
			cancelText: "NO",
			destructiveHandler: {
				action in

				guard action.style != .cancel else {
					completionHandler?()
					return
				}


				let originalCount = fileURLs.count
				var deletedCount: Int = 0
				var deletingError: Error? = nil
				do {
					for imageURL in fileURLs {
						try FileManager.default.removeItem(at: imageURL)

						do {
							try FileManager.default.removeItem(at: imageURL.jsonURL)
						}
						catch {
							// attempt with paired .jsonURL don't need to be caught
						}

						deletedCount = deletedCount + 1
					}
				}
				catch {	fxd_log()
					fxdPrint(error)
					deletingError = error
				}

				DispatchQueue.main.async {
					if deletedCount == originalCount {
						UIAlertController.simpleAlert(withTitle: "Deleted \(deletedCount) images", message: nil)
					}
					else {
						UIAlertController.errorAlert(error: deletingError)
					}
				}

				completionHandler?()
			})
	}
}


extension URL {
	public var jsonURL: URL {
		return self
			.deletingPathExtension()
			.appendingPathExtension(UTType.json.preferredFilenameExtension ?? UTType.json.identifier.components(separatedBy: ".").last ?? "json")
	}
}
