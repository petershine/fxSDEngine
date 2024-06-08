
import OSLog
import Foundation
import UIKit

import fXDKit


open class FXDobservableMain: NSObject, SDobservableMain {
	@Published open var overlayObservable: FXDobservableOverlay? = nil
	@Published open var progressObservable: SDcodableProgress? = nil

	@Published open var displayedImage: UIImage? = nil

	@Published open var shouldContinueRefreshing: Bool = false {
		didSet {
			if shouldContinueRefreshing == false {
				overlayObservable = nil
				progressObservable = nil
			}
		}
	}

	public init(overlayObservable: FXDobservableOverlay? = nil,
				progressObservable: SDcodableProgress? = nil,
				displayedImage: UIImage? = nil,
				shouldContinueRefreshing: Bool = false) {
		super.init()

		self.overlayObservable = overlayObservable
		self.progressObservable = progressObservable
		self.displayedImage = displayedImage
		self.shouldContinueRefreshing = shouldContinueRefreshing
	}
}


open class FXDmoduleMain: NSObject, SDmoduleMain {
	@Published open var observable: (any SDobservableMain)? = nil

	open var systemInfo: SDcodableSysInfo? = nil
	open var currentGenerationPayload: SDcodablePayload? {
		didSet {
			if let encodedPayload = currentGenerationPayload?.encodedPayload() {
				savePayloadToFile(payload: encodedPayload)
			}
		}
	}

	public init(observable: (any SDobservableMain)? = nil,
				systemInfo: SDcodableSysInfo? = nil,
				currentGenerationPayload: SDcodablePayload? = nil) {
		super.init()
		
		self.observable = observable
		self.systemInfo = systemInfo
		self.currentGenerationPayload = currentGenerationPayload
	}
}
