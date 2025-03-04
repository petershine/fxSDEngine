

import Foundation
import UIKit

import fXDKit


open class fxSDnetworkingBasic: NSObject, SDNetworking, @unchecked Sendable {
    open var serverHostname: String = {
        guard let savedHostname = UserDefaults.standard.value(forKey: USER_DEFAULT_HOSTNAME) else {
            return ""
        }

        return (savedHostname as? String) ?? ""
    }()

    public func evaluateServerHostname(serverHostname: String?) async -> Bool {    fxd_log()
        fxdPrint("serverHostname:", serverHostname)

        guard let serverHostname, !serverHostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }


        let httpRequest = httpRequest(
            serverHostname: serverHostname,
            api_endpoint: .INTERNAL_PING,
            method: nil,
            query: nil,
            payload: nil)

        let (data, response, error) = await requestToSDServer(
            quiet: false,
            request: httpRequest)
#if DEBUG
        if let jsonDictionary = data?.jsonDictionary(quiet: true) {
            fxdPrint(name: "INTERNAL_PING", dictionary: jsonDictionary)
        }
#endif
        guard data != nil,
              (response as? HTTPURLResponse)?.statusCode == 200,
              error == nil
        else {
            await UIAlertController.errorAlert(error: error, title: "Possibly, you entered wrong server hostname, or server is not operating.")

            return false
        }


        self.serverHostname = serverHostname.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serverHostname, forKey: Self.USER_DEFAULT_HOSTNAME)

        return true
    }

    public func httpRequest(
        serverHostname: String?,
        api_endpoint: SDAPIendpoint,
        method: String? = nil,
        query: String? = nil,
        payload: Data? = nil) -> URLRequest? {
            let serverHostname = serverHostname ?? self.serverHostname
            
            var requestPath = "\(serverHostname)/\(api_endpoint.rawValue)"
            if !(query?.isEmpty ?? true),
               let escapedQuery = query {	//query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
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
        request: URLRequest? = nil,
        api_endpoint: SDAPIendpoint? = nil,
        method: String? = nil,
        query: String? = nil,
        payload: Data? = nil) async -> (Data?, URLResponse?, Error?) {
			if !quiet {
				fxd_log()
			}

            var httpRequest = request
            if httpRequest == nil, let api_endpoint {
                httpRequest = self.httpRequest(
                    serverHostname: self.serverHostname,
                    api_endpoint: api_endpoint,
                    method: method,
                    query: query,
                    payload: payload)
            }
            guard let httpRequest else {
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
	

    public var responseHandler: ((Data?, URLResponse?, (any Error)?) -> Void)?
	fileprivate var receivedData: Data? = nil


    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "GenerArt")
//        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
}


extension fxSDnetworkingBasic: URLSessionDelegate, URLSessionDataDelegate {
    public func execute_backgroundURLtask(api_endpoint: SDAPIendpoint,
                                          method: String? = nil,
                                          query: String? = nil,
                                          payload: Data? = nil) {

        guard let httpRequest = httpRequest(
            serverHostname: self.serverHostname,
            api_endpoint: api_endpoint,
            method: method,
            query: query,
            payload: payload) else {
            return
        }


        let backgroundTask = urlSession.dataTask(with: httpRequest)
        backgroundTask.earliestBeginDate = Date.now
//        backgroundTask.countOfBytesClientExpectsToSend = 200
        backgroundTask.countOfBytesClientExpectsToReceive = 1024 * 1024 * 1024

        backgroundTask.resume()
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {	fxd_log()
        Task {	@MainActor in
            UIAlertController.errorAlert(error: error)
        }
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

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {	fxd_log()
        fxdPrint(session)
        fxdPrint(responseHandler)
        fxdPrint(receivedData)

        Task {    @MainActor in
            if let appDelegate = UIApplication.shared.delegate as? FXDAppDelegate,
               let completionHandler = appDelegate.backgroundCompletionHandler {
                
                fxdPrint(completionHandler)
            }
        }
    }
}
