import Foundation // Needed for URL

/// Represents the different categories of models used in Stable Diffusion backends.
public enum SDModelType: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
	case checkpoints = "Checkpoints" // Main diffusion models
	case vaes = "VAEs"               // Variational Autoencoders
	case samplers = "Samplers"           // Diffusion sampling algorithms
	case schedulers = "Schedulers"       // Noise schedulers (often linked to samplers)
	case upscalers = "Upscalers"         // Image upscaling models
	// Add future types here, e.g., Loras, TextualInversions, ControlNets

	/// Provides an identifiable raw value.
	public var id: String { self.rawValue }
}

/// Base protocol for all Stable Diffusion model description types.
/// Ensures models are Codable for API interaction, Hashable for use in collections,
/// Sendable for concurrency, and provide a display name and a unique identifier.
public protocol SDprotocolModel: Codable, Hashable, Sendable, Identifiable {
	/// A user-friendly display name, often derived from model_name or title. Optional.
	var name: String? { get set }

	/// A best-effort unique identifier for the model (e.g., sha256, hash, or name).
	var identifier: String { get }

	/// Provides a concise, user-readable description of the model.
	func displayDescription() -> String

	/// Optional: The local file path where this model is stored, once resolved. Transient.
	var localPath: URL? { get set }
}

// MARK: - Checkpoint Model

/// Represents a Stable Diffusion checkpoint model.
public struct SDcodableCheckpoint: SDprotocolModel {
	// MARK: SDprotocolModel Conformance
	public var name: String? {
		get { model_name } // Shorthand getter
		set { model_name = newValue } // Shorthand setter
	}

	public var identifier: String {
		sha256 ?? hash ?? title ?? model_name ?? filename ?? "unknown_checkpoint"
	}

	// MARK: Properties from API
	public var model_name: String? /// Often the user-friendly name displayed in UIs.
	public var title: String?      /// Usually matches `model_name`, sometimes more descriptive.
	public var hash: String?       /// Short hash (e.g., first 8-10 chars of SHA256) calculated by backend.
	public var sha256: String?     /// Full SHA256 hash, the most reliable identifier.
	public var filename: String?   /// The actual filename on the backend server.
	public var config: String?     /// Associated config file path (often for older models).

	// MARK: Local State (Transient)
	public var localPath: URL? // Path if found locally

	// MARK: Computed Properties
	/// Provides a more reliable display title, falling back through available fields.
	public var displayTitle: String {
		title ?? model_name ?? filename ?? "Untitled Checkpoint"
	}

	/// Heuristic check if the model is likely an SDXL model based on common naming conventions.
	public var isSDXL: Bool {
		let lowerName = (title ?? model_name ?? filename ?? "").lowercased()
		return lowerName.contains("sdxl") || lowerName.contains("sd_xl")
	}

	/// Heuristic check if the model is likely an inpainting model.
	public var isLikelyInpaint: Bool {
		let lowerName = (title ?? model_name ?? filename ?? "").lowercased()
		return lowerName.contains("inpaint")
	}

	// MARK: Methods
	public func displayDescription() -> String {
		var components: [String] = []
		components.append("Checkpoint: \(displayTitle)")
		if let id = sha256 ?? hash { components.append("ID: \(id.prefix(10))") }
		if isSDXL { components.append("Type: SDXL") }
		if isLikelyInpaint { components.append("Type: Inpaint") }
		return components.joined(separator: " | ")
	}

	// MARK: Codable Enhancement (Transient localPath)
	// Exclude localPath from Codable process
	private enum CodingKeys: String, CodingKey {
		case model_name, title, hash, sha256, filename, config // Keep API fields
		// localPath is omitted, making it transient
	}

	// Custom init to allow creation without localPath, required if CodingKeys is used
	public init(model_name: String? = nil, title: String? = nil, hash: String? = nil, sha256: String? = nil, filename: String? = nil, config: String? = nil, localPath: URL? = nil) {
		self.model_name = model_name
		self.title = title
		self.hash = hash
		self.sha256 = sha256
		self.filename = filename
		self.config = config
		self.localPath = localPath
	}
}

// MARK: - VAE Model

/// Represents a Stable Diffusion VAE (Variational Autoencoder) model.
public struct SDcodableVAE: SDprotocolModel {
	// MARK: SDprotocolModel Conformance
	public var name: String? {
		get { model_name }
		set { model_name = newValue }
	}

	public var identifier: String {
		// VAEs often lack unique hashes in standard APIs, rely on name/filename.
		model_name ?? filename ?? "unknown_vae"
	}

	// MARK: Properties from API
	public var model_name: String? /// The user-friendly name/identifier.
	public var filename: String?   /// The actual filename on the backend server.

	// MARK: Local State (Transient)
	public var localPath: URL?

	// MARK: Computed Properties
	/// Checks if this represents the 'Automatic' or 'None' VAE option.
	public var isAutoOrNone: Bool {
		model_name == SDcodableVAE.automatic.model_name || model_name == SDcodableVAE.none.model_name
	}

	// MARK: Static Instances
	/// Represents the default/automatic VAE selection.
	public static let automatic = SDcodableVAE(model_name: "Automatic", filename: nil)
	/// Represents selecting no specific VAE.
	public static let none = SDcodableVAE(model_name: "None", filename: nil)

	// MARK: Methods
	public func displayDescription() -> String {
		"VAE: \(name ?? "Untitled")" + (filename != nil ? " (\(filename!))" : "")
	}

	// MARK: Codable Enhancement (Transient localPath)
	private enum CodingKeys: String, CodingKey {
		case model_name, filename // Keep API fields
	}

	// Custom init to allow creation without localPath
	public init(model_name: String? = nil, filename: String? = nil, localPath: URL? = nil) {
		self.model_name = model_name
		self.filename = filename
		self.localPath = localPath
	}
}

// MARK: - Sampler Model

/// Represents a Stable Diffusion sampler algorithm.
public struct SDcodableSampler: SDprotocolModel {

	/// Nested struct holding specific options/characteristics of the sampler.
	public struct SDcodableSamplerOption: Codable, Hashable, Sendable {
		/// Associated noise scheduler type (if specified).
		public var scheduler: String?
		/// Solver type used (if applicable, e.g., for DPM).
		public var solver_type: String?
		/// Whether the sampler uses second-order information. Defaults to false.
		public var second_order: Bool
		/// Whether the sampler uses Brownian noise (stochastic vs deterministic). Defaults to false.
		public var brownian_noise: Bool
		/// Specific option for some samplers regarding sigma handling. Defaults to false.
		public var discard_next_to_last_sigma: Bool
		/// Whether the sampler uses ENSD (Euler Noise Step Delta). Defaults to false.
		public var uses_ensd: Bool? // Keep optional if API might omit entirely

		/// Custom decoder to handle boolean values that might be encoded as strings ("true"/"false").
		public init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			self.scheduler = try container.decodeIfPresent(String.self, forKey: .scheduler)
			self.solver_type = try container.decodeIfPresent(String.self, forKey: .solver_type)

			// Helper to decode Bool forgivingly (attempts Bool, then String "true"/"false")
			func decodeBoolForgivingly(key: CodingKeys) throws -> Bool {
				if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: key) {
					return boolValue
				}
				if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
					return stringValue.lowercased() == "true"
				}
				return false // Default to false if key missing or type mismatch after string check
			}

			self.second_order = try decodeBoolForgivingly(key: .second_order)
			self.brownian_noise = try decodeBoolForgivingly(key: .brownian_noise)
			self.discard_next_to_last_sigma = try decodeBoolForgivingly(key: .discard_next_to_last_sigma)
			self.uses_ensd = try decodeBoolForgivingly(key: .uses_ensd) // Uses default false now
		}

		// Conform to Codable requires specifying CodingKeys if using custom init
		private enum CodingKeys: String, CodingKey {
			case scheduler, solver_type, second_order, brownian_noise, discard_next_to_last_sigma, uses_ensd
		}
	}

	// MARK: SDprotocolModel Conformance
	public var name: String? /// The primary name of the sampler.
	public var identifier: String {
		name ?? "unknown_sampler"
	}
	public var localPath: URL? { // Samplers don't typically have local paths
		get { nil }
		set { /* No-op */ }
	}

	// MARK: Properties from API
	public var aliases: [String]? /// Alternative names for the sampler.
	public var options: SDcodableSamplerOption? /// Specific options/characteristics.

	// MARK: Computed Properties
	/// Checks if the sampler options indicate support for second order.
	public var supportsSecondOrder: Bool {
		options?.second_order ?? false
	}

	/// Checks if the sampler is likely deterministic based on Brownian noise option.
	public var isDeterministic: Bool {
		!(options?.brownian_noise ?? false) // Deterministic if Brownian noise is false or unspecified
	}

	/// Returns the associated scheduler type, if known.
	public var associatedSchedulerType: String? {
		options?.scheduler
	}

	// MARK: Methods
	public func displayDescription() -> String {
		var components: [String] = []
		components.append("Sampler: \(name ?? "Untitled")")
		if let opts = options {
			if opts.second_order { components.append("2nd Order") }
			if !(opts.brownian_noise) { components.append("Deterministic") } else { components.append("Stochastic") }
			if let scheduler = opts.scheduler { components.append("Scheduler: \(scheduler)") }
		}
		return components.joined(separator: " | ")
	}

	// Custom init if needed, e.g., for testing or manual creation
	public init(name: String?, aliases: [String]? = nil, options: SDcodableSamplerOption? = nil) {
		self.name = name
		self.aliases = aliases
		self.options = options
	}
}

// MARK: - Scheduler Model

/// Represents a Stable Diffusion noise scheduler.
public struct SDcodableScheduler: SDprotocolModel {
	// MARK: SDprotocolModel Conformance
	public var name: String? /// The internal/API name of the scheduler.
	public var identifier: String {
		name ?? label ?? "unknown_scheduler"
	}
	public var localPath: URL? { // Schedulers don't typically have local paths
		get { nil }
		set { /* No-op */ }
	}

	// MARK: Properties from API
	public var label: String? /// A user-friendly label for the scheduler.
	public var aliases: [String]? /// Alternative names.
	public var default_rho: Int?  /// Specific parameter for some schedulers.
	public var need_inner_model: Bool? /// Indicates if scheduler needs specific model properties.

	// MARK: Computed Properties
	/// Provides a display name, preferring the label over the internal name.
	public var displayName: String {
		label ?? name ?? "Untitled Scheduler"
	}

	// MARK: Methods
	public func displayDescription() -> String {
		"Scheduler: \(displayName)"
	}

	// Custom init if needed
	public init(name: String?, label: String? = nil, aliases: [String]? = nil, default_rho: Int? = nil, need_inner_model: Bool? = nil) {
		self.name = name
		self.label = label
		self.aliases = aliases
		self.default_rho = default_rho
		self.need_inner_model = need_inner_model
	}
}


// MARK: - Upscaler Model

/// Represents an image upscaling model.
public struct SDcodableUpscaler: SDprotocolModel {
	// MARK: SDprotocolModel Conformance
	// Name might be the user-friendly name, model_name might be internal
	public var name: String? /// User-friendly name.
	public var identifier: String {
		// Upscalers often identified by name, path might not be unique if copied
		name ?? model_name ?? model_path ?? "unknown_upscaler"
	}

	// MARK: Properties from API
	public var model_name: String? /// Internal or alternative name. Can be nil.
	public var model_path: String? /// File path on the backend server. Can be nil.
	public var model_url: String?  /// URL if the model definition comes from a URL. Can be nil.
	public var scale: Int?         /// The upscaling factor (e.g., 2, 4).

	// MARK: Local State (Transient)
	public var localPath: URL?

	// MARK: Computed Properties
	/// Provides a display name, falling back through available fields.
	public var displayName: String {
		name ?? model_name ?? (model_path != nil ? URL(fileURLWithPath: model_path!).lastPathComponent : nil) ?? "Untitled Upscaler"
	}

	/// Heuristic check if the upscaler is likely RealESRGAN based on name.
	public var isRealESRGAN: Bool {
		let lowerName = displayName.lowercased()
		return lowerName.contains("esrgan")
	}

	/// Heuristic: Checks if it might be a ControlNet model (less likely for upscalers, example).
	public var isControlNetModel: Bool {
		let lowerName = displayName.lowercased()
		return lowerName.contains("controlnet") || lowerName.contains("control_")
	}

	/// Returns the scale factor, defaulting to 1 if not specified.
	public var scaleFactor: Int {
		scale ?? 1 // Default to 1x if scale is unknown
	}

	// MARK: Static Instances
	/// Represents selecting no specific upscaler.
	public static let none = SDcodableUpscaler(name: "None", model_name: nil, model_path: nil, model_url: nil, scale: 1)

	// MARK: Methods
	public func displayDescription() -> String {
		var components: [String] = []
		components.append("Upscaler: \(displayName)")
		components.append("Scale: \(scaleFactor)x")
		if isRealESRGAN { components.append("Type: RealESRGAN") }
		return components.joined(separator: " | ")
	}

	// MARK: Codable Enhancement (Transient localPath)
	private enum CodingKeys: String, CodingKey {
		case name, model_name, model_path, model_url, scale // Keep API fields
	}

	// Custom init to allow creation without localPath
	public init(name: String? = nil, model_name: String? = nil, model_path: String? = nil, model_url: String? = nil, scale: Int? = nil, localPath: URL? = nil) {
		self.name = name
		self.model_name = model_name
		self.model_path = model_path
		self.model_url = model_url
		self.scale = scale
		self.localPath = localPath
	}
}

// Potential Future Enhancements (Comments):
// - Add methods to fetch extended metadata (e.g., from Civitai using sha256).
// - Implement more sophisticated version comparison if API provides sufficient data.
// - Add `Downloadable` protocol conformance with download status tracking.
// - Implement `func findLocalFile(searchDirectories: [URL]) -> URL?` methods.
