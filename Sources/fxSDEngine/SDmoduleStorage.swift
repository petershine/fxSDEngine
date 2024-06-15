
import Foundation

import fXDKit
import UniformTypeIdentifiers


open class SDmoduleStorage: NSObject {
	var savedPayloadURL: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		let fileURL = documentDirectory?.appendingPathComponent("savedPayload.json")
		return fileURL
	}

	open var savedImageURL: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"

		let fileName = dateFormatter.string(from: Date.now)
		let fileURL = documentDirectory?.appendingPathComponent("GenerArt_\(fileName).png")
		return fileURL
	}

	open var latestImageURLs: [URL]? {
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

	open func savePayloadToFile(payload: Data) async {	fxd_log()
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

	open func loadPayloadFromFile() throws -> Data? {
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

	func saveGeneratedImage(pngData: Data) async -> Bool {	fxd_log()
		fxdPrint("pngData: ", pngData)
		guard let fileURL = savedImageURL else {
			return false
		}

		do {
			try pngData.write(to: fileURL)
			fxdPrint("[IMAGE FILE SAVED]: ", fileURL)
			return true

		} catch {
			fxdPrint(error)
			return false
		}
	}
}
