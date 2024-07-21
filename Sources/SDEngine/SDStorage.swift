
import Foundation
import UIKit

import fXDKit
import UniformTypeIdentifiers


@Observable
open class SDStorage: NSObject {
	public var latestImageURLs: [URL]? = {
		return FileManager.default.fileURLs(contentType: .png)
	}()

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

	public func saveGenerated(pngData: Data, payloadData: Data?, index: Int = 0) async -> URL? {
		guard let imageURL = newFileURL(index: index, contentType: UTType.png) else {
			return nil
		}


		fxd_log()
		do {
			fxdPrint("pngData: ", pngData)
			try pngData.write(to: imageURL)
			fxdPrint("[IMAGE FILE SAVED]: ", imageURL)


			fxdPrint("payloadData: ", payloadData)
			try payloadData?.write(to: imageURL.jsonURL)
			fxdPrint("[PAYLOAD JSON SAVED]: ", imageURL.jsonURL)


            if let originalImage = UIImage(data: pngData) {
                let containerSize = CGSize(width: DIMENSION_MINIMUM_IMAGE, height: DIMENSION_MINIMUM_IMAGE)
                let thumbnailSize = originalImage.aspectSize(for: .fill, containerSize: containerSize)

                if let thumbnailImage = await UIImage(data: pngData)?.byPreparingThumbnail(ofSize: thumbnailSize) {
                    let thumbnailData = thumbnailImage.pngData()

                    fxdPrint("thumbnailData: ", thumbnailData)
                    try thumbnailData?.write(to: imageURL.thumbnailURL)
                    fxdPrint("[THUMBNAIL SAVED]: ", imageURL.thumbnailURL)
                }
            }

			return imageURL

		} catch {
			fxdPrint(error)
			return nil
		}
	}
}

extension SDStorage {
    public func deleteFileURLs(fileURLs: [URL?]?, completionHandler: ((Bool) -> Void)?) {
		guard let fileURLs, fileURLs.count > 0 else {
			completionHandler?(false)
			return
		}


		let message: String = (fileURLs.count > 1) ? "\(fileURLs.count) images" : ((fileURLs.first as? URL)?.absoluteURL.lastPathComponent ?? "")

		UIAlertController.simpleAlert(
			withTitle: "Do you want to delete?",
			message: message,
			destructiveText: "DELETE",
			cancelText: "NO",
			destructiveHandler: {
				action in

				guard action.style != .cancel else {
                    completionHandler?(false)
					return
				}


				let originalCount = fileURLs.count
				var deletedCount: Int = 0
				var deletingError: Error? = nil
				do {
					for fileURL in fileURLs {
                        guard let imageURL: URL = fileURL else {
                            continue
                        }

						try FileManager.default.removeItem(at: imageURL)

						do {
							try FileManager.default.removeItem(at: imageURL.jsonURL)

                            do {
                                try FileManager.default.removeItem(at: imageURL.thumbnailURL)
                            }
                            catch {
                                // attempt with paired .thumbnailURL don't need to be caught
                            }
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

				if deletedCount == originalCount {
					UIAlertController.simpleAlert(withTitle: "Deleted \(deletedCount) images", message: nil)
				}
				else {
					UIAlertController.errorAlert(error: deletingError)
				}

                completionHandler?(deletedCount > 0)
			})
	}
}
