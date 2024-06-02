

import Foundation


struct SDcodableSysInfo: SDcodableResponse {
	var Config: SDcodableConfig? = nil
	struct SDcodableConfig: Codable {
		var outdir_samples: String? = nil
	}

	var Extensions: [SDcodableExtension?]? = nil
	struct SDcodableExtension: Codable {
		var branch: String? = nil
		var name: String? = nil
		var path: String? = nil
		var remote: String? = nil
		var version: String? = nil
	}
}
