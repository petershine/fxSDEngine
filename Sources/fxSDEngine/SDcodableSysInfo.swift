

import Foundation


public struct SDcodableSysInfo: SDcodableResponse {
	var Config: SDcodableConfig? = nil
	struct SDcodableConfig: Codable {
		var outdir_samples: String? = nil
		var SCUNET_tile: Int? = nil
		var SCUNET_tile_overlap: Int? = nil
		var SWIN_tile: Int? = nil
		var SWIN_tile_overlap: Int? = nil
		var SWIN_torch_compile: Bool? = nil
		var hypertile_enable_unet: Bool? = nil
		var hypertile_enable_unet_secondpass: Bool? = nil
		var hypertile_enable_vae: Bool? = nil
		var hypertile_max_depth_unet: Int? = nil
		var hypertile_max_depth_vae: Int? = nil
		var hypertile_max_tile_unet: Int? = nil
		var hypertile_max_tile_vae: Int? = nil
		var hypertile_swap_size_unet: Int? = nil
		var hypertile_swap_size_vae: Int? = nil
		var ldsr_cached: Bool? = nil
		var ldsr_steps: Int? = nil
		var sd_checkpoint_hash: String? = nil
		var sd_model_checkpoint: String? = nil
	}
	
	public var Extensions: [SDcodableExtension?]? = nil
}

public struct SDcodableExtension: Codable {
	var branch: String? = nil
	var name: String? = nil
	var path: String? = nil
	var remote: String? = nil
	var version: String? = nil
}


extension SDcodableSysInfo {
	func generationFolder() -> String? {
		return Config?.outdir_samples
	}
}

/*
 Extensions =     (
			 {
		 branch = main;
		 name = adetailer;
		 path = "/Volumes/zzzz/_zSD/stable-diffusion-webui/extensions/adetailer";
		 remote = "https://github.com/Bing-su/adetailer";
		 version = a89c01d3;
	 },

 */
