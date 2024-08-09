

import Foundation


public struct SDcodableSysInfo: Codable {
	var Extensions: [SDcodableExtension]? = nil

	public var Config: SDcodableConfig? = nil
	public struct SDcodableConfig: Codable {
		public var outdir_samples: String? = nil

		public var sd_checkpoint_hash: String? = nil
		var sd_model_checkpoint: String? = nil

        public var sd_vae: String? = nil
	}
}


extension SDcodableSysInfo {
	public func isEnabled(_ extensionCase: SDExtensionName) -> Bool {
        let filtered = self.Extensions?.filter({
            return $0.name?.lowercased().contains(extensionCase.rawValue.lowercased()) ?? false
        })
        return (filtered ?? []).count > 0
	}
}
