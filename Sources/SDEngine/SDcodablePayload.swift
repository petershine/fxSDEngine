

import Foundation
import UIKit


public class SDcodablePayload: SDprotocolCodable, Equatable, @unchecked Sendable {
    public static func == (lhs: SDcodablePayload, rhs: SDcodablePayload) -> Bool {
        return false
    }

	public var prompt: String
	public var negative_prompt: String

	public var steps: Int
	public var cfg_scale: Double
    public var distilled_cfg_scale: Double
	public var sampler_name: String
	public var scheduler: String


	public var width: Int
	public var height: Int

    var hr_cfg: Double
    var hr_distilled_cfg: Double
    public var hr_scale: Double
    public var enable_hr: Bool
    var hr_resize_x: Int
    var hr_resize_y: Int
    var denoising_strength: Double
    var hr_second_pass_steps: Int
    public var hr_upscaler: String
    public var hr_sampler_name: String?
    public var hr_scheduler: String?
    var hr_prompt: String
    var hr_negative_prompt: String
    var highresfix_quick: Bool
    var hr_additional_modules: [String?]?

	public var n_iter: Int
	var batch_size: Int

	var save_images: Bool
	var send_images: Bool

	public var seed: Int
    var seed_enable_extras: Bool

	var do_not_save_samples: Bool
	var do_not_save_grid: Bool

    var override_settings_restore_afterwards: Bool
    public var override_settings: SDcodableOverride?
    public struct SDcodableOverride: Codable {
        public var sd_model_checkpoint: String?
        public var sd_vae: String?
        public var samples_save: Bool?
    }


    public var userConfiguration: SDcodableUserConfiguration

    /*
     comments: Dictionary
     disable_extra_networks: Bool
     restore_faces: Bool
     */


	required public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
		self.negative_prompt = try container.decodeIfPresent(String.self, forKey: .negative_prompt) ?? ""

		self.steps = try container.decodeIfPresent(Int.self, forKey: .steps) ?? 30
        self.cfg_scale = try container.decodeIfPresent(Double.self, forKey: .cfg_scale) ?? 6.0
        self.distilled_cfg_scale = try container.decodeIfPresent(Double.self, forKey: .distilled_cfg_scale) ?? 3.5
		self.sampler_name = try container.decodeIfPresent(String.self, forKey: .sampler_name) ?? "Euler a"
		self.scheduler = try container.decodeIfPresent(String.self, forKey: .scheduler) ?? "Polyexponential"

        self.width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 672
        self.height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1024

        self.hr_cfg = try container.decodeIfPresent(Double.self, forKey: .hr_cfg) ?? self.cfg_scale
        self.hr_distilled_cfg = try container.decodeIfPresent(Double.self, forKey: .hr_distilled_cfg) ?? 3.5
		self.hr_scale = try container.decodeIfPresent(Double.self, forKey: .hr_scale) ?? 1.0
		self.enable_hr = try container.decodeIfPresent(Bool.self, forKey: .enable_hr) ?? (self.hr_scale > 1.0)

        self.hr_resize_x = try container.decodeIfPresent(Int.self, forKey: .hr_resize_x) ?? 0
        self.hr_resize_y = try container.decodeIfPresent(Int.self, forKey: .hr_resize_y) ?? 0

        self.denoising_strength = try container.decodeIfPresent(Double.self, forKey: .denoising_strength) ?? 0.4
		self.hr_second_pass_steps = try container.decodeIfPresent(Int.self, forKey: .hr_second_pass_steps) ?? 10
		self.hr_upscaler = try container.decodeIfPresent(String.self, forKey: .hr_upscaler) ?? ""

        self.hr_sampler_name = try container.decodeIfPresent(String.self, forKey: .hr_sampler_name)
        if self.hr_sampler_name == nil {
            self.hr_sampler_name = self.sampler_name
        }
        
        self.hr_scheduler = try container.decodeIfPresent(String.self, forKey: .hr_scheduler)
        if self.hr_scheduler == nil {
            self.hr_scheduler = self.scheduler
        }

		self.hr_prompt = try container.decodeIfPresent(String.self, forKey: .hr_prompt) ?? ""
		self.hr_negative_prompt = try container.decodeIfPresent(String.self, forKey: .hr_negative_prompt) ?? ""
        self.highresfix_quick = try container.decodeIfPresent(Bool.self, forKey: .highresfix_quick) ?? false
        self.hr_additional_modules = try container.decodeIfPresent([String].self, forKey: .hr_additional_modules) ?? ["Use same choices"]

		self.n_iter = try container.decodeIfPresent(Int.self, forKey: .n_iter) ?? 1
		self.batch_size = try container.decodeIfPresent(Int.self, forKey: .batch_size) ?? 1

		self.save_images = try container.decodeIfPresent(Bool.self, forKey: .save_images) ?? true
		self.send_images = try container.decodeIfPresent(Bool.self, forKey: .send_images) ?? true

		self.seed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? -1
        self.seed_enable_extras = try container.decodeIfPresent(Bool.self, forKey: .seed_enable_extras) ?? true

		self.do_not_save_samples = try container.decodeIfPresent(Bool.self, forKey: .do_not_save_samples) ?? false
		self.do_not_save_grid = try container.decodeIfPresent(Bool.self, forKey: .do_not_save_grid) ?? false


        self.override_settings_restore_afterwards = try container.decodeIfPresent(Bool.self, forKey: .override_settings_restore_afterwards) ?? true
        self.override_settings = try container.decodeIfPresent(SDcodableOverride.self, forKey: .override_settings)

        self.userConfiguration = try container.decodeIfPresent(SDcodableUserConfiguration.self, forKey: .userConfiguration) ?? SDcodableUserConfiguration.minimum()!
	}
}

extension SDcodablePayload {
    public static func loaded(from fileURL: URL?, withControlNet: Bool) throws -> Self? {
        guard let loaded = try Self.loaded(from: fileURL) else {
            return nil
        }


        if withControlNet,
           let controlnet = try SDextensionControlNet.loaded(from: fileURL?.controlnetURL) {
            loaded.userConfiguration.controlnet = controlnet
        }

        return loaded
    }
}


import fXDKit

extension SDcodablePayload {
    public func submissablePayload(mainSDEngine: SDEngine) -> (Data?, SDextensionControlNet?) {
		guard let payload: Data = encoded() else {
			return (nil, nil)
		}


		var submissable: Dictionary<String, Any?>? = nil
		do {
			submissable = try JSONSerialization.jsonObject(with: payload) as? Dictionary<String, Any?>
		}
		catch {	fxd_log()
			fxdPrint(error)
		}

		guard var submissable else {
			return (nil, nil)
		}


        if !(self.userConfiguration.use_lastSeed) {
			submissable["seed"] = -1
		}


        var alwayson_scripts: [String:Any?] = [:]

        if (self.userConfiguration.use_adetailer),
           mainSDEngine.systemInfo?.isEnabled(.adetailer) ?? false {

            self.userConfiguration.adetailer.ad_cfg_scale = Int(self.cfg_scale)
            self.userConfiguration.adetailer.ad_denoising_strength = self.denoising_strength
            alwayson_scripts[SDExtensionName.adetailer.rawValue] = self.userConfiguration.adetailer.args
        }

        if (self.userConfiguration.use_controlnet) {
            if let sourceImageBase64 = self.userConfiguration.controlnet.image,
               !(sourceImageBase64.isEmpty) {
                alwayson_scripts[SDExtensionName.controlnet.rawValue] = self.userConfiguration.controlnet.args
            }
        }
        let utilizedControlNet = (self.userConfiguration.use_controlnet) ? self.userConfiguration.controlnet : nil

        if alwayson_scripts.count > 0 {
            submissable["alwayson_scripts"] = alwayson_scripts
        }


        var override_settings: [String:Any?]? = submissable["override_settings"] as? [String:Any?]
        override_settings?["samples_save"] = true
        submissable["override_settings"] = override_settings


        // clean userConfiguration, not for submission
        submissable["userConfiguration"] = nil


        var submissablePayload: Data = payload
        do {
            submissablePayload = try JSONSerialization.data(withJSONObject: submissable)
        }
        catch {    fxd_log()
            fxdPrint(error)
        }

        return (submissablePayload, utilizedControlNet)
	}
}

extension SDcodablePayload {
    public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {

        if let sizeComponents = (jsonDictionary["size"] as? String)?.components(separatedBy: "x"),
           sizeComponents.count == 2 {
            jsonDictionary["width"] = Int(sizeComponents.first ?? "672")
            jsonDictionary["height"] = Int(sizeComponents.last ?? "1024")
        }

        let replacingKeyPairs = [
            ("sampler_name", "sampler"),
            ("scheduler", "schedule type"),
            ("cfg_scale", "cfg scale"),

            ("denoising_strength", "denoising strength"),
            ("hr_scale", "hires upscale"),
            ("hr_second_pass_steps", "hires steps"),
            ("hr_upscaler", "hires upscaler"),

            ("model_hash", "model hash"),
        ]

        for (key, replacedKey) in replacingKeyPairs {
            jsonDictionary[key] = jsonDictionary[replacedKey]
            jsonDictionary[replacedKey] = nil
        }


        var override_settings: [String:String] = [:]

        if let model_hash = jsonDictionary["model_hash"] as? String, !model_hash.isEmpty {
            override_settings["sd_model_checkpoint"] = model_hash
        }
        else if let model_name = jsonDictionary["model"] as? String, !model_name.isEmpty {
            override_settings["sd_model_checkpoint"] = model_name
        }


        let vae_name: String = jsonDictionary["module 1"] as? String ?? jsonDictionary["vae"] as? String ?? ""
        if !vae_name.isEmpty {
            override_settings["sd_vae"] = vae_name
        }

        jsonDictionary["override_settings"] = override_settings


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
        guard let checkpointName = checkpoint.model_name,
              let overrideSettings = "{\"sd_model_checkpoint\" : \"\(checkpointName)\"}".processedJSONData()
        else {	fxd_log()
            fxdPrint(checkpoint)
            return
        }


        let decoded = try JSONDecoder().decode(SDcodableOverride.self, from: overrideSettings)
        if self.override_settings == nil {
            self.override_settings = decoded
        }
        else {
            self.override_settings?.sd_model_checkpoint = decoded.sd_model_checkpoint
        }
    }

    public func applyDefaultConfig(remoteConfig: SDDefaultConfig) {
        if self.prompt.isEmpty,
           let prompt = remoteConfig.prompt,
           !prompt.isEmpty {
            self.prompt = prompt
        }
        
        if self.negative_prompt.isEmpty,
           let negative_prompt = remoteConfig.negative_prompt,
           !negative_prompt.isEmpty {
            self.negative_prompt = negative_prompt
        }

        if self.hr_upscaler.isEmpty,
           let hr_upscaler = remoteConfig.hr_upscaler,
           !hr_upscaler.isEmpty {
            self.hr_upscaler = hr_upscaler
        }
    }
}


extension SDcodablePayload {
    public func configurations(with checkpoints: [SDcodableCheckpoint]) -> [[String]] {
        var model_name: String = "(unknown)"
        let model_identifier = override_settings?.sd_model_checkpoint ?? ""
        let filtered = checkpoints.filter { ($0.model_name == model_identifier || $0.hash == model_identifier) }
        if filtered.count == 0 {
            model_name = model_identifier.isEmpty ? "(unknown)" : model_identifier
        }
        else if filtered.first != nil {
            model_name = filtered.first?.model_name ?? "(unknown)"
        }

        let vae_name: String = override_settings?.sd_vae ?? "None"

        let essentials: [[String]] = [
            ["SEED:", String(seed)],

            ["MODEL:", model_name],
            ["VAE:", vae_name],
            ["SAMPLER:", sampler_name],
            ["SCHEDULER:", scheduler],
            ["STEPS:", String(Int(steps))],
            ["CFG:", String(format: "%.1f", cfg_scale)],

            ["WIDTH:", String(Int(width))],
            ["HEIGHT:", String(Int(height))],

            ["UPSCALER:", hr_upscaler],
            ["RESIZED:", "x\(String(format: "%.2f", hr_scale)) (\(String(Int(Double(width)*hr_scale))) by \(String(Int(Double(height)*hr_scale))))"],
        ]

        return essentials
    }
}


public struct SDcodableUserConfiguration: SDprotocolCodable {
    public var use_lastSeed: Bool
    public var use_adetailer: Bool
    public var use_controlnet: Bool

    public var adetailer: SDextensionADetailer
    public var controlnet: SDextensionControlNet


    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.use_lastSeed = try container.decodeIfPresent(Bool.self, forKey: .use_lastSeed) ?? false
        self.use_adetailer = try container.decodeIfPresent(Bool.self, forKey: .use_adetailer) ?? false
        self.use_controlnet = try container.decodeIfPresent(Bool.self, forKey: .use_controlnet) ?? false

        self.adetailer = try container.decodeIfPresent(SDextensionADetailer.self, forKey: .adetailer) ?? SDextensionADetailer.minimum()!
        self.controlnet = try container.decodeIfPresent(SDextensionControlNet.self, forKey: .controlnet) ?? SDextensionControlNet.minimum()!
    }
}
