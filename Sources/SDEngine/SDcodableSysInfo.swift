import Foundation

public struct SDcodableSysInfo: Codable {
	var Extensions: [SDcodableExtension]?

	public var Config: SDcodableConfig?
	public struct SDcodableConfig: Codable {
        var CLIP_stop_at_last_layers: Int?

		public var outdir_samples: String?
        public var outdir_txt2img_samples: String?

		public var sd_checkpoint_hash: String?
		var sd_model_checkpoint: String?

        public var sd_vae: String?

        var quick_setting_list: [String?]?
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
