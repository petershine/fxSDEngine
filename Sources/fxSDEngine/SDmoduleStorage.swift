
import Foundation

import fXDKit


open class SDmoduleStorage: NSObject {
	var savedPayloadJSONurl: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		let fileURL = documentDirectory?.appendingPathComponent("savedPayload.json")
		return fileURL
	}

	open var savedImageFileURL: URL? {
		let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		let fileURL = documentDirectory?.appendingPathComponent("savedImage.png")
		return fileURL
	}

	public override init() {
		super.init()
	}

	open func savePayloadToFile(payload: Data) {	fxd_log()
		fxdPrint("payload: ", payload)
		guard let fileURL = savedPayloadJSONurl else {
			return
		}

		do {
			try payload.write(to: fileURL)
			fxdPrint("[PAYLOAD JSON SAVED]: ", fileURL)
		} catch {
			fxdPrint(error)
		}
	}

	func loadPayloadFromFile() -> Data? {
		guard let fileURL = savedPayloadJSONurl else {
			return nil
		}


		var payloadData: Data? = nil
		do {
			payloadData = try Data(contentsOf: fileURL)
		} catch {	fxd_log()
			fxdPrint(error)
		}

		return payloadData
	}

	func saveGeneratedImage(pngData: Data) async -> Bool {	fxd_log()
		fxdPrint("pngData: ", pngData)
		guard let fileURL = savedImageFileURL else {
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
