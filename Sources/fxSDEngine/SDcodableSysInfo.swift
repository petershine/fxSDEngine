

import Foundation


public struct SDcodableSysInfo: Codable {
	var Extensions: [SDcodableExtension]? = nil

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
}

extension SDcodableSysInfo {
	public func generationFolder() -> String? {
		return Config?.outdir_samples
	}
}
