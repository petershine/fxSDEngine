
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
    func saveGenerated(pngData: Data, payloadData: Data?, controlnetData: Data?, index: Int = 0) async throws -> URL? {
        guard let imageURL = URL.newFileURL(prefix: "GenerArt", index: index, contentType: UTType.png) else {
			return nil
		}


		fxd_log()
        try pngData.write(to: imageURL)
        fxdPrint("[IMAGE FILE SAVED]: ", pngData, imageURL)

        try payloadData?.write(to: imageURL.jsonURL)
        fxdPrint("[PAYLOAD JSON SAVED]: ", payloadData, imageURL.jsonURL)

        if let controlnetData {
            try controlnetData.write(to: imageURL.controlnetURL)
            fxdPrint("[CONTROLNET JSON SAVED]: ", controlnetData, imageURL.controlnetURL)
        }

        let _ = try await saveThumbnail(imageURL: imageURL, pngData: pngData)

        return imageURL
	}

    func saveThumbnail(imageURL: URL, pngData: Data?) async throws -> Bool {
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


extension SDStorage {
    @MainActor public func deleteFileURLs(fileURLs: [URL?]?) async throws -> Bool {
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
                        try FileManager.default.removeItem(at: imageURL.jsonURL)
                        try FileManager.default.removeItem(at: imageURL.thumbnailURL)
                        try FileManager.default.removeItem(at: imageURL.controlnetURL)

                        deletedCount = deletedCount + 1
                    }
                }
                catch {    fxd_log()
                    fxdPrint(error)
                    UIAlertController.errorAlert(error: error)
                    return (false, error)
                }


                if deletedCount == originalCount {
                    UIAlertController.simpleAlert(withTitle: "Deleted \(deletedCount) images")
                }

                return ((deletedCount > 0), nil)
            })

        return didDelete ?? false
    }
}


fileprivate extension URL {
    var controlnetURL: URL {
        var controlNet = self.deletingPathExtension()
        let filenameComponent = controlNet.lastPathComponent
        controlNet.deleteLastPathComponent()
        controlNet.append(component: "_controlnet")
        controlNet.append(components: filenameComponent)
        controlNet.appendPathExtension(UTType.json.preferredFilenameExtension ?? UTType.json.identifier.components(separatedBy: ".").last ?? "json")

        return controlNet
    }
}
