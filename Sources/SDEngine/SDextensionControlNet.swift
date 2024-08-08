

import Foundation

import fXDKit


public struct SDextensionControlNet: Codable {
    var advanced_weighting: String? = nil
    var animatediff_batch: Bool? = false
    var batch_image_files: [String?]? = nil
    var batch_images: String? = ""
    var batch_keyframe_idx: String? = nil
    var batch_mask_dir: String? = nil
    var batch_modifiers: [String?]? = nil
    var control_mode: String? = "My prompt is more important"
    var effective_region_mask: String? = nil
    var enabled: Bool? = true
    var guidance_end: Double? = 1.0
    var guidance_start: Double? = 0.0
    var hr_option: String? = "Both"
    var inpaint_crop_input_image: Bool? = false
    var input_mode: String? = "simple"
    var ipadapter_input: String? = nil
    var is_ui: Bool? = true
    var loopback: Bool? = false
    var low_vram: Bool? = false
    var mask: String? = nil
    var model: String? = "control_v11p_sd15_lineart [43d4be0d]"
    var module: String? = "lineart_realistic"
    var output_dir: String? = ""
    var pixel_perfect: Bool? = true
    var processor_res: Int? = 512
    var pulid_mode: String? = "Fidelity"
    var resize_mode: String? = "Resize and Fill"
    var save_detected_map: Bool? = true
    var threshold_a: Double? = 0.5
    var threshold_b: Double? = 0.5
    var weight: Double? = 1.0

    public struct SDextensionControlNetImage: Codable {
        var image: String? = "base64image placeholder"
        var mask: String? = "base64image placeholder"
    }

//    public init(from decoder: any Decoder) throws {
//    }
}


extension SDextensionControlNet: SDprotocolExtension {
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
    
    public static func decoded(using jsonDictionary: inout Dictionary<String, Any?>) -> Self? {
        return nil
    }
}
