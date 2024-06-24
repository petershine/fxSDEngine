

public struct SDcodableModel: Codable, Hashable {
	public var model_name: String?
	var title: String?
	var hash: String?
	var sha256: String?
	var filename: String?
	var config: String?
}


//https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/7839
struct SDcodableOptions: Codable {
	var sd_model_checkpoint: String?
}
