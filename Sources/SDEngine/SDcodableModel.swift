

public enum SDModelType: String, CaseIterable {
    case checkpoints
    case vaes
    case samplers
    case schedulers
    case upscalers
}

public protocol SDprotocolModel: Codable, Hashable, Sendable {
    var name: String? { get set }
}


public struct SDcodableCheckpoint: SDprotocolModel {
    public var name: String? {
        get {
            return model_name
        }
        set {
            model_name = newValue
        }
    }

    public var model_name: String?
    public var title: String?
    public var hash: String?
    var sha256: String?
    var filename: String?
    var config: String?
}

public struct SDcodableVAE: SDprotocolModel {
    public var name: String? {
        get {
            return model_name
        }
        set {
            model_name = newValue
        }
    }

    var model_name: String?
    var filename: String?
}

extension SDcodableVAE {
    static func defaultArray() -> [SDcodableVAE] {
        return [SDcodableVAE(model_name: "Automatic"), SDcodableVAE(model_name: "None")]
    }
}

public struct SDcodableSampler: SDprotocolModel {
    public var name: String?

    var aliases: [String?]?
    var options: SDcodableSamplerOption?
    struct SDcodableSamplerOption: Codable, Hashable {
        var scheduler: String?
        var solver_type: String?
        var second_order: Bool?
        var brownian_noise: Bool?
        var discard_next_to_last_sigma: Bool?
        var uses_ensd: Bool?

        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<SDcodableSampler.SDcodableSamplerOption.CodingKeys> = try decoder.container(keyedBy: SDcodableSampler.SDcodableSamplerOption.CodingKeys.self)

            self.scheduler = try container.decodeIfPresent(String.self, forKey: SDcodableSampler.SDcodableSamplerOption.CodingKeys.scheduler)
            self.solver_type = try container.decodeIfPresent(String.self, forKey: SDcodableSampler.SDcodableSamplerOption.CodingKeys.solver_type)

            do {
                self.second_order = try container.decodeIfPresent(Bool.self, otherType: String.self, forKey: SDcodableSampler.SDcodableSamplerOption.CodingKeys.second_order)
                self.brownian_noise = try container.decodeIfPresent(Bool.self, otherType: String.self, forKey: SDcodableSampler.SDcodableSamplerOption.CodingKeys.brownian_noise)
                self.discard_next_to_last_sigma = try container.decodeIfPresent(Bool.self, otherType: String.self, forKey: SDcodableSampler.SDcodableSamplerOption.CodingKeys.discard_next_to_last_sigma)
                self.uses_ensd = try container.decodeIfPresent(Bool.self, otherType: String.self, forKey: SDcodableSampler.SDcodableSamplerOption.CodingKeys.uses_ensd)
            }
            catch {
                // For they are optional, they don't need to fail whole decoding
            }
        }
    }
}

public struct SDcodableScheduler: SDprotocolModel {
	public var name: String?

    var label: String?
    var aliases: [String?]?
    var default_rho: Int?
    var need_inner_model: Bool?
}

public struct SDcodableUpscaler: SDprotocolModel {
    public var name: String?
    var model_name: String?
    var model_path: String?
    var model_url: String?
    var scale: Int?
}
