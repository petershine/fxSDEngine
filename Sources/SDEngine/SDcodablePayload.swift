

import Foundation
import UIKit

import fXDKit

public struct SDcodableOverride: Codable {
    public var sd_model_checkpoint: String?
}

public class SDcodablePayload: Codable, Equatable, ObservableObject {
	public static func == (lhs: SDcodablePayload, rhs: SDcodablePayload) -> Bool {
		return lhs.seed == rhs.seed
	}

	public var prompt: String
	public var negative_prompt: String

	public var steps: Int
	public var cfg_scale: Double
	public var sampler_name: String
	public var scheduler: String


	public var width: Int
	public var height: Int

	public var hr_scale: Double
	public var enable_hr: Bool
	var denoising_strength: Double
	var hr_second_pass_steps: Int
	var hr_upscaler: String
	var hr_scheduler: String
	var hr_prompt: String
	var hr_negative_prompt: String

	public var n_iter: Int
	var batch_size: Int

	var save_images: Bool
	var send_images: Bool

	public var seed: Int

	var do_not_save_samples: Bool
	var do_not_save_grid: Bool

    var override_settings_restore_afterwards: Bool
    public var override_settings: SDcodableOverride?


    // externally editable
    public var use_lastSeed: Bool
    public var use_adetailer: Bool


	required public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
		self.negative_prompt = try container.decodeIfPresent(String.self, forKey: .negative_prompt) ?? ""

		self.steps = try container.decodeIfPresent(Int.self, forKey: .steps) ?? 30
		self.cfg_scale = try container.decodeIfPresent(Double.self, forKey: .cfg_scale) ?? 7.0
		self.sampler_name = try container.decodeIfPresent(String.self, forKey: .sampler_name) ?? "DPM++ 2M SDE"
		self.scheduler = try container.decodeIfPresent(String.self, forKey: .scheduler) ?? "Karras"


		var aspectRatio = UIScreen.main.nativeBounds.size.width/UIScreen.main.nativeBounds.size.height
		if UIDevice.current.userInterfaceIdiom == .phone {
			aspectRatio = max(504.0/768.0, aspectRatio)
		}
		
		self.height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 768
		self.width = try container.decodeIfPresent(Int.self, forKey: .width) ?? Int(CGFloat(self.height) * aspectRatio)

		self.hr_scale = try container.decodeIfPresent(Double.self, forKey: .hr_scale) ?? 1.0
		self.enable_hr = try container.decodeIfPresent(Bool.self, forKey: .enable_hr) ?? (self.hr_scale > 1.0)

		self.denoising_strength = try container.decodeIfPresent(Double.self, forKey: .denoising_strength) ?? 0.3
		self.hr_second_pass_steps = try container.decodeIfPresent(Int.self, forKey: .hr_second_pass_steps) ?? 10
		self.hr_upscaler = try container.decodeIfPresent(String.self, forKey: .hr_upscaler) ?? "4x-UltraSharp"
		self.hr_scheduler = try container.decodeIfPresent(String.self, forKey: .hr_scheduler) ?? "Karras"
		self.hr_prompt = try container.decodeIfPresent(String.self, forKey: .hr_prompt) ?? ""
		self.hr_negative_prompt = try container.decodeIfPresent(String.self, forKey: .hr_negative_prompt) ?? ""

		self.n_iter = try container.decodeIfPresent(Int.self, forKey: .n_iter) ?? 1
		self.batch_size = try container.decodeIfPresent(Int.self, forKey: .batch_size) ?? 1

		self.save_images = try container.decodeIfPresent(Bool.self, forKey: .save_images) ?? true
		self.send_images = try container.decodeIfPresent(Bool.self, forKey: .send_images) ?? true

		self.seed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? -1

		self.do_not_save_samples = try container.decodeIfPresent(Bool.self, forKey: .do_not_save_samples) ?? false
		self.do_not_save_grid = try container.decodeIfPresent(Bool.self, forKey: .do_not_save_grid) ?? false


        self.override_settings_restore_afterwards = try container.decodeIfPresent(Bool.self, forKey: .override_settings_restore_afterwards) ?? true
        self.override_settings = try container.decodeIfPresent(SDcodableOverride.self, forKey: .override_settings)

		// externally editable
		self.use_lastSeed = try container.decodeIfPresent(Bool.self, forKey: .use_lastSeed) ?? false
		self.use_adetailer = try container.decodeIfPresent(Bool.self, forKey: .use_adetailer) ?? false
	}
}


extension SDcodablePayload {
	public func extendedPayload(sdEngine: SDEngine) -> Data? {
		guard let payload: Data = encoded() else {
			return nil
		}


		var extendedDictionary: Dictionary<String, Any?>? = nil
		do {
			extendedDictionary = try JSONSerialization.jsonObject(with: payload) as? Dictionary<String, Any?>
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		guard extendedDictionary != nil else {
			return nil
		}


		if !self.use_lastSeed {
			extendedDictionary?["seed"] = -1
		}

		if self.use_adetailer,
		   sdEngine.systemInfo?.isEnabled(.adetailer) ?? false {

			var alwayson_scripts: Dictionary<String, Any?> = [:]
			alwayson_scripts[SDExtensionName.adetailer.rawValue] = SDExtensionName.adetailer.arguments()

			if alwayson_scripts.count > 0 {
				extendedDictionary?["alwayson_scripts"] = alwayson_scripts
			}
		}


		// clean unnecessary keys
        extendedDictionary?["use_lastSeed"] = nil
		extendedDictionary?["use_adetailer"] = nil


		var extendedPayload: Data = payload
		do {
			extendedPayload = try JSONSerialization.data(withJSONObject: extendedDictionary!)
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		return extendedPayload
	}
}

extension SDcodablePayload {
    public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {

        if let sizeComponents = (jsonDictionary["size"] as? String)?.components(separatedBy: "x"),
           sizeComponents.count == 2 {
            jsonDictionary["width"] = Int(sizeComponents.first ?? "504")
            jsonDictionary["height"] = Int(sizeComponents.last ?? "768")
        }

        let replacingKeyPairs = [
            ("sampler_name", "sampler"),
            ("scheduler", "schedule type"),
            ("cfg_scale", "cfg scale"),

            ("denoising_strength", "denoising strength"),
            ("hr_scale", "hires upscale"),
            ("hr_second_pass_steps", "hires steps"),
            ("hr_upscaler", "hires upscaler"),
        ]

        for (key, replacedKey) in replacingKeyPairs {
            jsonDictionary[key] = jsonDictionary[replacedKey]
            jsonDictionary[replacedKey] = nil
        }

        let model_hash: String = (jsonDictionary["model hash"] ?? jsonDictionary["model_hash"]) as? String ?? ""
        if !model_hash.isEmpty {
            jsonDictionary["override_settings"] = ["sd_model_checkpoint" : model_hash]
        }


        var decoded: Self? = nil
        do {
            let payloadData = try JSONSerialization.data(withJSONObject: jsonDictionary)
            decoded = try JSONDecoder().decode(Self.self, from: payloadData)
            fxdPrint(decoded!)
        }
        catch {
            fxdPrint(error)
        }

        return decoded
    }

    public func update(with checkpoint: SDcodableModel) {
        guard let model_hash = checkpoint.hash,
              let overrideSettings = "{\"sd_model_checkpoint\" : \"\(model_hash)\"}".processedJSONData()
        else {	fxd_log()
            fxdPrint(checkpoint)
            return
        }


        do {
            self.override_settings = try JSONDecoder().decode(SDcodableOverride.self, from: overrideSettings)
        }
        catch {    fxd_log()
            fxdPrint(error)
        }
    }
}


extension SDcodablePayload {
    @MainActor public static func loaded(from imageURL: URL?) async -> Self? {
        guard let jsonURL = imageURL?.jsonURL else {
            return nil
        }

        var loaded: Self? = nil
        do {
            let payloadData = try Data(contentsOf: jsonURL)
            loaded = payloadData.decode(Self.self)
        }
        catch {    fxd_log()
            fxdPrint(error)
        }

        return loaded
    }

    @MainActor public func configurations(with checkpoints: [SDcodableModel]) async -> [[String]] {
        var model_name: String = "(unknown)"
        let model_hash = override_settings?.sd_model_checkpoint ?? ""
        if !model_hash.isEmpty {
            let filtered = checkpoints.filter { $0.hash == model_hash }

            if filtered.first != nil {
                model_name = filtered.first?.model_name ?? "(unknown)"
            }
        }

        let essentials: [[String]] = [
            ["MODEL: ", model_name],
            ["SAMPLER: ", sampler_name],
            ["SCHEDULER: ", scheduler],
            ["STEPS: ", String(Int(steps))],
            ["CFG: ", String(format: "%.1f", cfg_scale)],

            ["WIDTH: ", String(Int(width))],
            ["HEIGHT: ", String(Int(height))],
            ["RESIZED: ", "x\(String(format: "%.2f", hr_scale)) (\(String(Int(Double(width)*hr_scale))) by \(String(Int(Double(height)*hr_scale))))"],

            ["SEED:", String(seed)],
        ]

        return essentials
    }
}
