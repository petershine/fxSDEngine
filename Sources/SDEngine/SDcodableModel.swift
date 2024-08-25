

public enum SDModelType: String, CaseIterable {
    case checkpoints
    case vaes
    case samplers
    case schedulers
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
        var second_order: Bool?
        var brownian_noise: Bool?
        var solver_type: String?
        var discard_next_to_last_sigma: Bool?
        var uses_ensd: Bool?
    }
}

public struct SDcodableScheduler: SDprotocolModel {
	public var name: String?

    var label: String?
    var aliases: [String?]?
    var default_rho: Int?
    var need_inner_model: Bool?
}

