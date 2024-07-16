

public struct SDcodableModel: Codable, Hashable {
	public var model_name: String?
	public var title: String?
	public var hash: String?
	var sha256: String?
	var filename: String?
	var config: String?
}

public struct SDcodableSampler: Codable {
    var name: String?
    var aliases: [String?]?
    var options: SDcodableSamplerOption?
    struct SDcodableSamplerOption: Codable {
        var scheduler: String?
        var second_order: String?
        var brownian_noise: String?
        var solver_type: String?
        var discard_next_to_last_sigma: String?
        var uses_ensd: String?
    }
}

public struct SDcodableScheduler: Codable {
	var name: String?
    var label: String?
    var aliases: [String?]?
    var default_rho: Int?
    var need_inner_model: String?
}
