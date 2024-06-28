
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
		guard  let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
			return nil
		}

		var fileURLs: [URL]? = nil
		do {
			let contents = try FileManager.default.contentsOfDirectory(
				at: documentDirectory,
				includingPropertiesForKeys: [.contentModificationDateKey, .contentTypeKey],
				options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])

			fileURLs = try contents
				.filter {
					let resourceValues: URLResourceValues = try $0.resourceValues(forKeys: [.contentTypeKey])
					return resourceValues.contentType == UTType.png
				}
				.sorted {
					let resourceValues_0: URLResourceValues = try $0.resourceValues(forKeys: [.contentModificationDateKey])
					let resourceValues_1: URLResourceValues = try $1.resourceValues(forKeys: [.contentModificationDateKey])
					return resourceValues_0.contentModificationDate  ?? Date.now > resourceValues_1.contentModificationDate ?? Date.now
				}
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return fileURLs
	}


	public override init() {
		super.init()
	}
}

extension SDmoduleStorage {
	func savePayloadToFile(payload: Data) {	fxd_log()
		fxdPrint("payload: ", payload)
		guard let fileURL = savedPayloadURL else {
			return
		}

		do {
			try payload.write(to: fileURL)
			fxdPrint("[PAYLOAD JSON SAVED]: ", fileURL)
		} catch {
			fxdPrint(error)
		}
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

	fileprivate func newImageURL(index: Int) -> URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"

		let fileName = dateFormatter.string(from: Date.now)
		let fileURL = documentDirectory?.appendingPathComponent("GenerArt_\(fileName)_\(index).png")
		return fileURL
	}

	func saveGeneratedImage(pngData: Data, index: Int = 0) async -> URL? {	fxd_log()
		fxdPrint("pngData: ", pngData)
		guard let fileURL = newImageURL(index: index) else {
			return nil
		}

		do {
			try pngData.write(to: fileURL)
			fxdPrint("[IMAGE FILE SAVED]: ", fileURL)
			return fileURL

		} catch {
			fxdPrint(error)
			return nil
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
