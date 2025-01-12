

import Foundation


fileprivate enum SDcontrolnetMode: String, CaseIterable {
    case balanced = "Balanced"
    case myPrompt = "My prompt is more important"
    case controlNet = "ControlNet is more important"
}

public struct SDextensionControlNet: SDprotocolCodable, Equatable {
    var advanced_weighting: String?
    var animatediff_batch: Bool
    var batch_image_dir: String?
    var batch_input_gallery: String?
    var batch_image_files: [String?]?
    var batch_images: String
    var batch_keyframe_idx: String?
    var batch_mask_dir: String?
    var batch_mask_gallery: String?
    var batch_modifiers: [String?]?
    var control_mode: String
    var effective_region_mask: String?
    var enabled: Bool
    var generated_image: String?
    var guidance_end: Double
    var guidance_start: Double
    var hr_option: String
    var inpaint_crop_input_image: Bool
    var input_mode: String
    var ipadapter_input: String?
    var is_ui: Bool
    var loopback: Bool
    var low_vram: Bool
    var mask: String?
    public var model: String
    public var module: String
    var output_dir: String
    var pixel_perfect: Bool
    var processor_res: Double
    var pulid_mode: String
    var resize_mode: String
    var save_detected_map: Bool
    var threshold_a: Double
    var threshold_b: Double
    var use_preview_as_input: Bool
    var weight: Double

    public var image: String?
    var image_fg: String?
    var mask_image: String?
    var mask_image_fg: String?


    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.advanced_weighting = try container.decodeIfPresent(String.self, forKey: .advanced_weighting) ?? nil
        self.animatediff_batch = try container.decodeIfPresent(Bool.self, forKey: .animatediff_batch) ?? false
        self.batch_image_dir = try container.decodeIfPresent(String.self, forKey: .batch_image_dir) ?? nil
        self.batch_input_gallery = try container.decodeIfPresent(String.self, forKey: .batch_input_gallery) ?? nil
        self.batch_image_files = try container.decodeIfPresent([String?].self, forKey: .batch_image_files) ?? nil
        self.batch_images = try container.decodeIfPresent(String.self, forKey: .batch_images) ?? ""
        self.batch_keyframe_idx = try container.decodeIfPresent(String.self, forKey: .batch_keyframe_idx) ?? nil
        self.batch_mask_dir = try container.decodeIfPresent(String.self, forKey: .batch_mask_dir) ?? nil
        self.batch_mask_gallery = try container.decodeIfPresent(String.self, forKey: .batch_mask_gallery) ?? nil
        self.batch_modifiers = try container.decodeIfPresent([String?].self, forKey: .batch_modifiers) ?? nil
        self.control_mode = try container.decodeIfPresent(String.self, forKey: .control_mode) ?? SDcontrolnetMode.myPrompt.rawValue
        self.effective_region_mask = try container.decodeIfPresent(String.self, forKey: .effective_region_mask) ?? nil
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.generated_image = try container.decodeIfPresent(String.self, forKey: .generated_image) ?? nil
        self.guidance_end = try container.decodeIfPresent(Double.self, forKey: .guidance_end) ?? 1.0
        self.guidance_start = try container.decodeIfPresent(Double.self, forKey: .guidance_start) ?? 0.0
        self.hr_option = try container.decodeIfPresent(String.self, forKey: .hr_option) ?? "Both"
        self.inpaint_crop_input_image = try container.decodeIfPresent(Bool.self, forKey: .inpaint_crop_input_image) ?? false
        self.input_mode = try container.decodeIfPresent(String.self, forKey: .input_mode) ?? "simple"
        self.ipadapter_input = try container.decodeIfPresent(String.self, forKey: .ipadapter_input) ?? nil
        self.is_ui = try container.decodeIfPresent(Bool.self, forKey: .is_ui) ?? true
        self.loopback = try container.decodeIfPresent(Bool.self, forKey: .loopback) ?? false
        self.low_vram = try container.decodeIfPresent(Bool.self, forKey: .low_vram) ?? false
        self.mask = try container.decodeIfPresent(String.self, forKey: .mask) ?? nil
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? "controlnetxlCNXL_abovzvSegment [49e0ea4a]"
        self.module = try container.decodeIfPresent(String.self, forKey: .module) ?? "seg_ofade20k"
        self.output_dir = try container.decodeIfPresent(String.self, forKey: .output_dir) ?? ""
        self.pixel_perfect = try container.decodeIfPresent(Bool.self, forKey: .pixel_perfect) ?? true
        self.processor_res = try container.decodeIfPresent(Double.self, forKey: .processor_res) ?? 0.5
        self.pulid_mode = try container.decodeIfPresent(String.self, forKey: .pulid_mode) ?? "Fidelity"
        self.resize_mode = try container.decodeIfPresent(String.self, forKey: .resize_mode) ?? "Resize and Fill"
        self.save_detected_map = try container.decodeIfPresent(Bool.self, forKey: .save_detected_map) ?? true
        self.threshold_a = try container.decodeIfPresent(Double.self, forKey: .threshold_a) ?? 0.5
        self.threshold_b = try container.decodeIfPresent(Double.self, forKey: .threshold_b) ?? 0.5
        self.use_preview_as_input = try container.decodeIfPresent(Bool.self, forKey: .use_preview_as_input) ?? false
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 1.0

        self.image = try container.decodeIfPresent(String.self, forKey: .image) ?? nil
        self.image_fg = try container.decodeIfPresent(String.self, forKey: .image_fg) ?? nil
        self.mask_image = try container.decodeIfPresent(String.self, forKey: .mask_image) ?? nil
        self.mask_image_fg = try container.decodeIfPresent(String.self, forKey: .mask_image_fg) ?? nil
    }
}


import fXDKit

extension SDextensionControlNet: SDprotocolExtension {
    public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {
        var extractedDictionary: [String:Any?] = [:]
        let extractingKeyPairs_controlnet = [
            ("control_mode", "control mode"),
            ("module", "controlnet 0"),
            ("model", "model"),
            ("guidance_end", "guidance end"),
            ("guidance_start", "guidance start"),
            ("pixel_perfect", "pixel perfect"),
            ("processor_res", "processor res"),
            ("resize_mode", "resize mode"),
            ("threshold_a", "threshold a"),
            ("threshold_b", "threshold b"),
        ]
        for (key, extractedKey) in extractingKeyPairs_controlnet {
            extractedDictionary[key] = jsonDictionary[extractedKey]
            jsonDictionary[extractedKey] = nil
        }


        let control_mode = extractedDictionary["control_mode"] as? String
        for controlMode in SDcontrolnetMode.allCases {
            if (control_mode?.contains(controlMode.rawValue) ?? false) {
                extractedDictionary["control_mode"] = controlMode.rawValue
            }
        }

        fxdPrint(name: "extractedDictionary", dictionary: extractedDictionary)

        var decoded: Self? = nil
        if extractedDictionary.count > 0,
           let _ = extractedDictionary["module"] {
            do {
                let controlnetData = try JSONSerialization.data(withJSONObject: extractedDictionary)
                decoded = try JSONDecoder().decode(Self.self, from: controlnetData)
                fxdPrint(decoded!)
            }
            catch {
                fxdPrint(error)
            }
        }
        fxdPrint("decoded:", decoded)

        return decoded
    }

    public var args: Dictionary<String, Any?>? {
        var args: Dictionary<String, Any?>? = nil
        do {
            args = [
                "args" : [
                    try JSONEncoder().encode(self).jsonDictionary() ?? [:],
                ]
            ]
        }
        catch {    fxd_log()
            fxdPrint(error)
        }

        return args
    }
    
    public func configurations() -> [[String]] {
        let essentials: [[String]] = [
            ["module:", module],
            ["model:", model],
            ["control mode:", control_mode],
            ["resize mode:", resize_mode],
        ]

        return essentials
    }
}
