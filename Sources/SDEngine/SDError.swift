
import Foundation

import fXDKit


public let ERROR_NOT_OPERATING: String = "Possibly, your ForgeUI server is not operating."

public class SDError: NSError, @unchecked Sendable {
    public var httpURLResponse: HTTPURLResponse? = nil

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    required override init(domain: String, code: Int, userInfo dict: [String : Any]? = nil) {
        super.init(domain: domain, code: code, userInfo: dict)
    }

    class func processsed(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Self? {
        guard !(error is Self) else {
            return error as? Self
        }

        guard error != nil
                || data != nil
                || response != nil else {
            return error as? Self
        }

        let httpURLResponseStatusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard httpURLResponseStatusCode != 200 else {
            return error as? Self
        }


        let assumedDescription = "Problem with server"
        var assumedFailureReason = ""
        switch httpURLResponseStatusCode {
            case 404:
                assumedFailureReason = ERROR_NOT_OPERATING
            default:
                break
        }


        let jsonDictionary: [String:Any?]? = data?.jsonDictionary()

        var errorDescription = (error as? NSError)?.localizedDescription ?? assumedDescription
        errorDescription += "\n\(jsonDictionary?["error"] as? String ?? "")"

        let receivedDetail = "\n\(jsonDictionary?["detail"] as? String ?? "")"
        if receivedDetail != errorDescription {
            errorDescription += receivedDetail
        }
        errorDescription = errorDescription.trimmingCharacters(in: .whitespacesAndNewlines)


        var errorFailureReason = (error as? NSError)?.localizedFailureReason ?? assumedFailureReason
        errorFailureReason += "\n\(jsonDictionary?["errors"] as? String ?? "")"

        var receivedMSG = "\n\(jsonDictionary?["msg"] as? String ?? "")"
        if receivedMSG.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let detail = jsonDictionary?["detail"] as? Array<Dictionary<String, Any>> {
                receivedMSG = "\n\(detail.first?["msg"] as? String ?? "")"
            }
        }
        if receivedMSG != errorFailureReason {
            errorFailureReason += receivedMSG
        }
        errorFailureReason = errorFailureReason.trimmingCharacters(in: .whitespacesAndNewlines)


        let errorUserInfo = [
            NSLocalizedDescriptionKey : errorDescription,
            NSLocalizedFailureReasonErrorKey : errorFailureReason
        ]

        let processed = Self(
            domain: "SDEngine",
            code: (error as? NSError)?.code ?? -1,
            userInfo: errorUserInfo)
        processed.httpURLResponse = response as? HTTPURLResponse


        fxd_log()
        fxdPrint(name: "DATA", dictionary: jsonDictionary)
        fxdPrint("RESPONSE", response)
        fxdPrint("ERROR", error)
        fxdPrint("PROCESSED", processed)

        return processed
    }
}

