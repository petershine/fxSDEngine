

import Foundation
import UIKit

import fXDKit


open class fxSDnetworkingBasic: NSObject, @unchecked Sendable, SDNetworking {
	open var serverHostname: String {
		return "http://127.0.0.1:7860"
	}

    public func httpRequest(
        api_endpoint: SDAPIendpoint,
        method: String? = nil,
        query: String? = nil,
        payload: Data? = nil) -> URLRequest? {
            var requestPath = "\(serverHostname)/\(api_endpoint.rawValue)"
            if !(query?.isEmpty ?? true),
               let escapedQuery = query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                requestPath += "?\(escapedQuery)"
            }

            guard let requestURL = URL(string: requestPath) else {
                return nil
            }


            var httpRequest = URLRequest(url: requestURL)
            httpRequest.timeoutInterval = .infinity
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            httpRequest.httpMethod = method ?? "GET"
            if payload != nil {
                fxdPrint(name: "PAYLOAD", dictionary: payload?.jsonDictionary())
                httpRequest.httpMethod = "POST"
                httpRequest.httpBody = payload
            }

            return httpRequest
    }

    public func requestToSDServer(
        quiet: Bool = false,
        api_endpoint: SDAPIendpoint,
        method: String? = nil,
        query: String? = nil,
        payload: Data? = nil) async -> (Data?, URLResponse?, Error?) {
			if !quiet {
				fxd_log()
			}

            guard let httpRequest = httpRequest(api_endpoint: api_endpoint, method: method, query: query, payload: payload) else {
                return (nil, nil, nil)
            }


            var data: Data? = nil
            var response: URLResponse? = nil
            var error: Error? = nil

            do {
                (data, response) = try await URLSession.shared.data(for: httpRequest)
            }
            catch let httpError {
                error = httpError
            }
            

            let statusCode = (response as? HTTPURLResponse)?.statusCode
            fxdPrint("response.statusCode: ", statusCode, quiet:quiet)
            fxdPrint("data: ", data, quiet:quiet)
            fxdPrint("error: ", error, quiet:quiet)

            if data == nil || statusCode != 200 {
                fxdPrint("httpURLResponse: ", (response as? HTTPURLResponse))

                fxdPrint("httpRequest.url: ", httpRequest.url)
                fxdPrint("httpRequest.allHTTPHeaderFields: ", httpRequest.allHTTPHeaderFields)
                fxdPrint("httpRequest.httpMethod: ", httpRequest.httpMethod)
                fxdPrint("httpRequest.httpBody: ", httpRequest.httpBody)
            }

            let processedError = SDError.processsed(data, response, error)
            return (data, response, processedError)
		}
	

	fileprivate var responseHandler: ((Data?, URLResponse?, (any Error)?) -> Void)?
	fileprivate var receivedData: Data? = nil
}


extension fxSDnetworkingBasic: URLSessionDelegate, URLSessionDataDelegate {
	public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {	fxd_log()
        UIAlertController.errorAlert(error: error)
	}

	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		if receivedData == nil {
			receivedData = Data()
		}
		receivedData?.append(data)
		fxdPrint(receivedData)
	}

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        self.responseHandler?(self.receivedData, task.response, error)

        self.responseHandler = nil
        self.receivedData = nil
	}
}
