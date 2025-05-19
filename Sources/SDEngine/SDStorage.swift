
import Foundation
import UIKit
import UniformTypeIdentifiers

import fXDKit


extension URL {
    public var controlnetURL: URL? {
        return self.pairedFileURL(inSubPath: "_controlnet", contentType: .json)
    }
}


@Observable
open class SDStorage: @unchecked Sendable {
    public var latestImageURLs: [URL]? = nil

    public init(latestImageURLs: [URL]? = FileManager.default.fileURLs(contentType: .png)) {
        self.latestImageURLs = latestImageURLs
    }
}

extension SDStorage {
    func saveGenerated(pngData: Data, payloadData: Data?, controlnetData: Data?, index: Int = 0) async throws -> URL? {
        guard let fileURL = URL.newFileURL(prefix: "GenerArt", index: index, contentType: UTType.png) else {
			return nil
		}


		fxd_log()
        try pngData.writeInsideDirectory(to: fileURL)
        fxdPrint("[IMAGE FILE SAVED]: ", pngData, fileURL)

        if let jsonURL = fileURL.jsonURL {
            try payloadData?.writeInsideDirectory(to: jsonURL)
            fxdPrint("[PAYLOAD JSON SAVED]: ", payloadData, jsonURL)
        }

        let _ = try await saveControlnet(fileURL: fileURL, controlnetData: controlnetData)
        let _ = try await saveThumbnail(fileURL: fileURL, pngData: pngData)

        latestImageURLs = FileManager.default.fileURLs(contentType: .png)
        return fileURL
	}

    fileprivate func saveControlnet(fileURL: URL, controlnetData: Data?) async throws -> Bool {
        guard let controlnetData else {
            return false
        }

        guard let controlnetURL = fileURL.controlnetURL else {
            return false
        }

        
        try controlnetData.writeInsideDirectory(to: controlnetURL)
        fxdPrint("[CONTROLNET JSON SAVED]: ", controlnetData, controlnetURL)

        return true
    }

    fileprivate func saveThumbnail(fileURL: URL, pngData: Data?) async throws -> Bool {
        guard let pngData,
              let pngImage = UIImage(data: pngData) else {
            return false
        }


        let thumbnailSize = await pngImage.aspectSize(for: .fill, containerSize: CGSize(width: DIMENSION_MINIMUM_IMAGE, height: DIMENSION_MINIMUM_IMAGE))
        guard let thumbnail = await pngImage.byPreparingThumbnail(ofSize: thumbnailSize) else {
            return false
        }


        guard let thumbnailURL = fileURL.thumbnailURL else {
            return false
        }


        let thumbnailData = thumbnail.pngData()
        try thumbnailData?.writeInsideDirectory(to: thumbnailURL)
        fxdPrint("[THUMBNAIL SAVED]: ", thumbnailData, thumbnailURL)

        return true
    }
}


extension SDStorage {
    public func deleteFileURLs(fileURLs: [URL?]?) async throws -> Bool {
        guard let fileURLs, fileURLs.count > 0 else {
            return false
        }


        let message: String = (fileURLs.count > 1) ? "\(fileURLs.count) images" : ((fileURLs.first as? URL)?.absoluteURL.lastPathComponent ?? "")

        let didDelete = try await UIAlertController.asyncAlert(
            withTitle: "Do you want to delete?",
            message: message,
            cancelText: "NO",
            destructiveText: "DELETE",
            destructiveHandler: {
                action in

                let originalCount = fileURLs.count
                var deletedCount: Int = 0
                do {
                    for fileURL in fileURLs {
                        guard let imageURL: URL = fileURL else {
                            continue
                        }

                        try FileManager.default.removeItem(at: imageURL)
                        if let jsonURL = imageURL.jsonURL {
                            try FileManager.default.removeItem(at: jsonURL)
                        }

                        do {
                            if let controlnetURL = imageURL.controlnetURL {
                                try FileManager.default.removeItem(at: controlnetURL)
                            }
                            if let thumbnailURL = imageURL.thumbnailURL {
                                try FileManager.default.removeItem(at: thumbnailURL)
                            }
                        }
                        catch {
                            // It's okay. controlnet, or thumbnail, may not always be there
                            fxdPrint(error)
                        }

                        deletedCount = deletedCount + 1
                    }
                }
                catch {    fxd_log()
                    fxdPrint(error)
                    Task {	@MainActor in
                        UIAlertController.errorAlert(error: error)
                    }
                    return (false, error)
                }


                if deletedCount == originalCount {
                    Task {    @MainActor in
                        UIAlertController.simpleAlert(withTitle: "Deleted \(deletedCount) images")
                    }
                }

                return ((deletedCount > 0), nil)
            })

        latestImageURLs = FileManager.default.fileURLs(contentType: .png)
        return didDelete ?? false
    }
}
