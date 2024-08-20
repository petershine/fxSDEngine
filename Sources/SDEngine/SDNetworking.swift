
import Foundation
import UIKit


public enum SDAPIendpoint: String, CaseIterable {
	case INTERNAL_SYSINFO = "internal/sysinfo"

	case SDAPI_V1_TXT2IMG = "sdapi/v1/txt2img"
	case SDAPI_V1_PROGRESS = "sdapi/v1/progress"
	case SDAPI_V1_INTERRUPT = "sdapi/v1/interrupt"
	case SDAPI_V1_OPTIONS = "sdapi/v1/options"
	case SDAPI_V1_MODELS = "sdapi/v1/sd-models"
    case SDAPI_V1_SAMPLERS = "sdapi/v1/samplers"
    case SDAPI_V1_SCHEDULERS = "sdapi/v1/schedulers"
    case SDAPI_V1_VAE = "sdapi/v1/sd-vae"


	case INFINITE_IMAGE_BROWSING_FILES = "infinite_image_browsing/files"
	case INFINITE_IMAGE_BROWSING_FILE = "infinite_image_browsing/file"
	case INFINITE_IMAGE_BROWSING_GENINFO = "infinite_image_browsing/image_geninfo"
}


public protocol SDNetworking {
	var serverHostname: String { get set }

    func evaluateEnteredServerHostname(enteredServerHostname: String?)

    func httpRequest(
        serverHostname: String?,
        api_endpoint: SDAPIendpoint,
        method: String?,
        query: String?,
        payload: Data?) -> URLRequest?

	func requestToSDServer(
		quiet: Bool,
        request: URLRequest?,
		api_endpoint: SDAPIendpoint,
		method: String?,
		query: String?,
        payload: Data?) async -> (Data?, URLResponse?, Error?)
}
