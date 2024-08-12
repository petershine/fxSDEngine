

import Foundation
import UIKit

import fXDKit


public class SDcodablePayload: SDprotocolCodable, ObservableObject, @unchecked Sendable, Equatable {
    public static func == (lhs: SDcodablePayload, rhs: SDcodablePayload) -> Bool {
        return false
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
    public struct SDcodableOverride: Codable {
        public var sd_model_checkpoint: String?
        public var sd_vae: String?
        public var samples_save: Bool?
    }


    public var userConfiguration: SDcodableUserConfiguration?


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

        self.userConfiguration = try container.decodeIfPresent(SDcodableUserConfiguration.self, forKey: .userConfiguration)
        if self.userConfiguration == nil {
            self.userConfiguration = SDcodableUserConfiguration.minimum()
        }
	}
}

extension SDcodablePayload {
    public static func loaded(from fileURL: URL?, withControlNet: Bool) throws -> Self? {
        guard let loaded = try Self.loaded(from: fileURL) else {
            return nil
        }


        if withControlNet,
           let controlnet = try SDextensionControlNet.loaded(from: fileURL?.controlnetURL) {
            loaded.userConfiguration?.controlnet = controlnet
        }

        return loaded
    }
}


extension SDcodablePayload {
    public func submissablePayload(mainSDEngine: SDEngine) -> (Data?, SDextensionControlNet?) {
		guard let payload: Data = encoded() else {
			return (nil, nil)
		}


		var extendedDictionary: Dictionary<String, Any?>? = nil
		do {
			extendedDictionary = try JSONSerialization.jsonObject(with: payload) as? Dictionary<String, Any?>
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		guard extendedDictionary != nil else {
			return (nil, nil)
		}


        if !(self.userConfiguration?.use_lastSeed ?? false) {
			extendedDictionary?["seed"] = -1
		}


        var alwayson_scripts: Dictionary<String, Any?> = [:]

        if (self.userConfiguration?.use_adetailer ?? false),
           mainSDEngine.systemInfo?.isEnabled(.adetailer) ?? false {

            self.userConfiguration?.adetailer?.ad_cfg_scale = Int(self.cfg_scale)
            alwayson_scripts[SDExtensionName.adetailer.rawValue] = self.userConfiguration?.adetailer?.args
        }

        if (self.userConfiguration?.use_controlnet ?? false),
           mainSDEngine.systemInfo?.isEnabled(.controlnet) ?? false {
            
            if let sourceImageBase64 = self.userConfiguration?.controlnet?.image?.image,
               !(sourceImageBase64.isEmpty) {
                alwayson_scripts[SDExtensionName.controlnet.rawValue] = self.userConfiguration?.controlnet?.args
            }
        }

        if alwayson_scripts.count > 0 {
            extendedDictionary?["alwayson_scripts"] = alwayson_scripts
        }


        var override_settings: [String:Any?]? = extendedDictionary?["override_settings"] as? [String:Any?]
        override_settings?["samples_save"] = true
        extendedDictionary?["override_settings"] = override_settings


		// clean userConfiguration, not for submission
        extendedDictionary?["userConfiguration"] = nil


		var extendedPayload: Data = payload
		do {
			extendedPayload = try JSONSerialization.data(withJSONObject: extendedDictionary!)
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

        return (extendedPayload, self.userConfiguration?.controlnet)
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

    public func update(with checkpoint: SDcodableCheckpoint) throws {
        guard let model_hash = checkpoint.hash,
              let overrideSettings = "{\"sd_model_checkpoint\" : \"\(model_hash)\"}".processedJSONData()
        else {	fxd_log()
            fxdPrint(checkpoint)
            return
        }


        self.override_settings = try JSONDecoder().decode(SDcodableOverride.self, from: overrideSettings)
    }
}


extension SDcodablePayload {
    public func configurations(with checkpoints: [SDcodableCheckpoint]) -> [[String]] {
        var model_name: String = "(unknown)"
        let model_hash = override_settings?.sd_model_checkpoint ?? ""
        if !model_hash.isEmpty {
            let filtered = checkpoints.filter { $0.hash == model_hash }
            if filtered.first != nil {
                model_name = filtered.first?.model_name ?? "(unknown)"
            }
        }

        var essentials: [[String]] = [
            ["MODEL: ", model_name],
            ["SAMPLER: ", sampler_name],
            ["SCHEDULER: ", scheduler],
            ["STEPS: ", String(Int(steps))],
            ["CFG: ", String(format: "%.1f", cfg_scale)],

            ["WIDTH: ", String(Int(width))],
            ["HEIGHT: ", String(Int(height))],
            ["RESIZED: ", "x\(String(format: "%.2f", hr_scale)) (\(String(Int(Double(width)*hr_scale))) by \(String(Int(Double(height)*hr_scale))))"],

            ["SEED: ", String(seed)],
        ]

        essentials.append(["ADETAILER: ", (userConfiguration?.use_adetailer ?? false) ? "YES" : "NO"])
        essentials.append(["CONTROLNET: ", (userConfiguration?.use_controlnet ?? false) ? "YES" : "NO"])

        return essentials
    }
}


public struct SDcodableUserConfiguration: SDprotocolCodable {
    public var use_lastSeed: Bool
    public var use_adetailer: Bool
    public var use_controlnet: Bool

    public var controlnet: SDextensionControlNet? = nil
    public var adetailer: SDextensionADetailer? = nil


    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.use_lastSeed = try container.decodeIfPresent(Bool.self, forKey: .use_lastSeed) ?? false
        self.use_adetailer = try container.decodeIfPresent(Bool.self, forKey: .use_adetailer) ?? false
        self.use_controlnet = try container.decodeIfPresent(Bool.self, forKey: .use_controlnet) ?? false

        self.controlnet = try container.decodeIfPresent(SDextensionControlNet.self, forKey: .controlnet)
        self.adetailer = try container.decodeIfPresent(SDextensionADetailer.self, forKey: .adetailer)

        if self.controlnet == nil {
            self.controlnet = SDextensionControlNet.minimum()
        }

        if self.adetailer == nil {
            self.adetailer = SDextensionADetailer.minimum()
        }
    }
}
