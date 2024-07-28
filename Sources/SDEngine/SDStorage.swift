
import Foundation
import UIKit

import fXDKit
import UniformTypeIdentifiers


@Observable
open class SDStorage: NSObject {
	public var latestImageURLs: [URL]? = {
		return FileManager.default.fileURLs(contentType: .png)
	}()

	public override required init() {
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

	func saveGenerated(pngData: Data, payloadData: Data?, index: Int = 0) async throws -> URL? {
		guard let imageURL = newFileURL(index: index, contentType: UTType.png) else {
			return nil
		}


		fxd_log()
        try pngData.write(to: imageURL)
        fxdPrint("[IMAGE FILE SAVED]: ", pngData, imageURL)

        try payloadData?.write(to: imageURL.jsonURL)
        fxdPrint("[PAYLOAD JSON SAVED]: ", payloadData, imageURL.jsonURL)

        let _ = try await saveThumbnail(imageURL: imageURL, pngData: pngData)

        return imageURL
	}
}

extension SDStorage {
    @MainActor public func deleteFileURLs(fileURLs: [URL?]?) async throws -> Bool {
        guard let fileURLs, fileURLs.count > 0 else {
            return false
        }


        let message: String = (fileURLs.count > 1) ? "\(fileURLs.count) images" : ((fileURLs.first as? URL)?.absoluteURL.lastPathComponent ?? "")

        let deletingResult = try await withCheckedThrowingContinuation({
            (continuation: CheckedContinuation<Bool, Error>) in

            UIAlertController.simpleAlert(
                withTitle: "Do you want to delete?",
                message: message,
                destructiveText: "DELETE",
                cancelText: "NO",
                destructiveHandler: {
                    action in

                    guard action.style != .cancel else {
                        continuation.resume(returning: false)
                        return
                    }


                    let originalCount = fileURLs.count
                    var deletedCount: Int = 0
                    do {
                        for fileURL in fileURLs {
                            guard let imageURL: URL = fileURL else {
                                continue
                            }

                            try FileManager.default.removeItem(at: imageURL)
                            try FileManager.default.removeItem(at: imageURL.jsonURL)
                            try FileManager.default.removeItem(at: imageURL.thumbnailURL)

                            deletedCount = deletedCount + 1
                        }
                    }
                    catch {    fxd_log()
                        fxdPrint(error)
                        UIAlertController.errorAlert(error: error)
                        continuation.resume(throwing: error)
                        return
                    }


                    if deletedCount == originalCount {
                        UIAlertController.simpleAlert(withTitle: "Deleted \(deletedCount) images", message: nil)
                    }

                    continuation.resume(returning: deletedCount > 0)
                })
        })

        return deletingResult
    }
}

    func saveThumbnail(imageURL: URL, pngData: Data? = nil) async throws -> Bool {
        var imageData: Data? = pngData
        if imageData == nil {
            imageData = try Data(contentsOf: imageURL)
        }

        guard imageData != nil,
              let pngImage = UIImage(data: imageData!) else {
            return false
        }


        let thumbnailSize = pngImage.aspectSize(for: .fill, containerSize: CGSize(width: DIMENSION_MINIMUM_IMAGE, height: DIMENSION_MINIMUM_IMAGE))
        guard let thumbnailImage = await UIImage(data: imageData!)?.byPreparingThumbnail(ofSize: thumbnailSize) else {
            return false
        }


        let thumbnailData = thumbnailImage.pngData()
        let thumbnailURL = imageURL.thumbnailURL

        let thumbnailDirectory = thumbnailURL.deletingPathExtension().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)

        try thumbnailData?.write(to: thumbnailURL)
        fxdPrint("[THUMBNAIL SAVED]: ", thumbnailData, thumbnailURL)

        return true
    }
}
