
import Foundation
import UIKit

import fXDKit
import UniformTypeIdentifiers


open class SDmoduleStorage: NSObject {
	var savedPayloadURL: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		let fileURL = documentDirectory?.appendingPathComponent("savedPayload.json")
		return fileURL
	}

	public var latestImageURLs: [URL]? {
		return FileManager.default.fileURLs(contentType: .png)
	}

	public var latestPayloadURLs: [URL]? {
		return FileManager.default.fileURLs(contentType: .json)
	}


	public override init() {
		super.init()
	}
}

extension SDmoduleStorage {
	fileprivate func newFileURL(index: Int, contentType: UTType) -> URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"

		let fileName = dateFormatter.string(from: Date.now)
		let fileURL = documentDirectory?.appendingPathComponent("GenerArt_\(fileName)_\(index).\(contentType.preferredFilenameExtension ?? contentType.identifier.components(separatedBy: ".").last ?? "png")")
		return fileURL
	}

	public func loadPayloadFromFile() throws -> Data? {
		guard let fileURL = savedPayloadURL else {
			return nil
		}


		var payloadData: Data? = nil
		do {
			payloadData = try Data(contentsOf: fileURL)
		} catch {
			throw error
		}

		return payloadData
	}



	func saveGenerated(pngData: Data, payloadData: Data?, index: Int = 0) async -> (imageURL: URL?, payloadURL: URL?) {
		guard let imageURL = newFileURL(index: index, contentType: UTType.png) else {
			return (nil, nil)
		}
		
		let jsonURL = imageURL
			.deletingPathExtension()
			.appendingPathExtension(UTType.json.preferredFilenameExtension ?? UTType.json.identifier.components(separatedBy: ".").last ?? "json")


		fxd_log()
		do {
			fxdPrint("pngData: ", pngData)
			try pngData.write(to: imageURL)
			fxdPrint("[IMAGE FILE SAVED]: ", imageURL)


			fxdPrint("payloadData: ", payloadData)
			try payloadData?.write(to: jsonURL)
			fxdPrint("[PAYLOAD JSON SAVED]: ", jsonURL)

			return (imageURL, jsonURL)

		} catch {
			fxdPrint(error)
			return (nil, nil)
		}
	}
}

extension SDmoduleStorage {
	public func deleteImageURLs(imageURLs: [URL], completionHandler: (() -> Void)?) {
		guard imageURLs.count > 0 else {
			completionHandler?()
			return
		}


		let message: String = (imageURLs.count > 1) ? "\(imageURLs.count) images" : (imageURLs.first?.absoluteURL.lastPathComponent ?? "")

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


				let originalCount = imageURLs.count
				var deletedCount: Int = 0
				var deletingError: Error? = nil
				do {
					for fileURL in imageURLs {
						try FileManager.default.removeItem(at: fileURL)
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
