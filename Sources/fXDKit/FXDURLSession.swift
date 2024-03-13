

import Foundation
import UIKit


extension URLSession {
	public func synchronousURLRequest(urlRequest: URLRequest, asyncOperation: BlockOperation?, synchronousDataHandling:((Data?)->Void)?) {
		assert((Thread.isMainThread == false || asyncOperation == nil), "\(#function) : Thread.isMainThread : \(Thread.isMainThread), asyncOperation == nil : \(asyncOperation == nil)")
		guard (Thread.isMainThread == false || asyncOperation == nil) else {
			return	// while this operation is synchronous, it should be run inside non-mainThread, for data transferring and data transforming, without blocking mainThread
		}


		var retrievedData: Data? = nil

		let synchronousRequestSemaphore = DispatchSemaphore(value: 0)
		self.dataTask(with: urlRequest) {
			(data, response, error) in
			retrievedData = data

			if error != nil {
				fxdPrint("[\(#function)] error: \(String(describing: error))\nresponse: \(String(describing: response))")
			}

			synchronousRequestSemaphore.signal()
		}.resume()
		let result = synchronousRequestSemaphore.wait(timeout: .distantFuture)
		fxdPrint("[\(#function)] semaphore result : \(result)")

		fxdPrint("[\(#function)] cancelled during transferring: \(asyncOperation?.isCancelled ?? true)")
		fxdPrint("[\(#function)] retrievedData : \(String(describing: retrievedData))")

		synchronousDataHandling?(retrievedData)
	}


	public func synchronousImageRequest(urlRequest: URLRequest, asyncOperation: BlockOperation?) -> UIImage? {
		assert((Thread.isMainThread == false || asyncOperation == nil), "\(#function) : Thread.isMainThread : \(Thread.isMainThread), asyncOperation == nil : \(asyncOperation == nil)")
		guard (Thread.isMainThread == false || asyncOperation == nil) else {
			return nil	// while this operation is synchronous, it should be run inside non-mainThread, for data transferring and data transforming, without blocking mainThread
		}


		var retrievedImage: UIImage? = nil

		URLSession.shared.synchronousURLRequest(
			urlRequest: urlRequest,
			asyncOperation: asyncOperation,
			synchronousDataHandling: {
				(imageData) in
				guard imageData != nil else {
					return
				}

				guard (asyncOperation == nil || asyncOperation!.isCancelled == false) else {
					return
				}

				retrievedImage = UIImage(data: imageData!)
			})

		guard (asyncOperation == nil || asyncOperation!.isCancelled == false) else {
			fxdPrint("[\(#function)] cancelled during transforming : \(asyncOperation?.isCancelled ?? true)")
			return nil
		}

		return retrievedImage
	}
}


public let TIMEOUT_DEFAULT = 60.0	// ... "The default timeout interval is 60 seconds." ...
public let TIMEOUT_LONGER = (TIMEOUT_DEFAULT*2.0)

public enum SerializedURLRequestError: Error {
	case noRequests
	case userCancelled
	case timeoutExpired
}

@available(iOS 17.0, *)
public actor DataAndResponseActor {
	var dataAndResponseTuples: [(Data, URLResponse)] = []

	func assign(_ newArray: [(Data, URLResponse)]) {
		dataAndResponseTuples = newArray
	}
	func append(_ newElement: (Data, URLResponse)) {
		dataAndResponseTuples.append(newElement)
	}
	func count() -> Int {
		return dataAndResponseTuples.count
	}

	var caughtError: Error? = nil
	func assignError(_ newError: Error?) {
		caughtError = newError
	}
}

@available(iOS 17.0, *)
extension URLSession {
	public func startSerializedURLRequest(urlRequests: [URLRequest], progressConfiguration: FXDconfigurationInformation? = nil) async throws -> DataAndResponseActor? {
		guard urlRequests.count > 0 else {
			throw SerializedURLRequestError.noRequests
		}


		let safeDataAndResponse = DataAndResponseActor()
		func requesting(urlRequest: URLRequest, reattemptedRequests: [URLRequest] = []) async throws {
			guard !(progressConfiguration?.cancellableTask?.isCancelled ?? false) else {
				fxdPrint("[\(#function)] isCancelled: \((progressConfiguration?.cancellableTask?.isCancelled ?? false))")
				throw SerializedURLRequestError.userCancelled
			}

			let (data, response) = try await self.data(for: urlRequest)
			guard (response as? HTTPURLResponse)?.statusCode == 200 else {
				throw SerializedURLRequestError.timeoutExpired
			}


			await safeDataAndResponse.append((data, response))

			let finishedCount = await safeDataAndResponse.count()
			let progressValue: CGFloat = CGFloat(Float(finishedCount)/Float(urlRequests.count+reattemptedRequests.count))
			DispatchQueue.main.async {
				progressConfiguration?.sliderValue = progressValue
			}
		}

		var reattemptedRequests: [URLRequest] = []
		for urlRequest in urlRequests {
			do {
				try await requesting(urlRequest: urlRequest)
			}
			catch {
				guard let urlError = error as? URLError,
					  urlError.code.rawValue == NSURLErrorTimedOut else {
					fxdPrint("[\(#function)] \(error)")
					throw error
				}


				var modifiedRequest = urlRequest
				modifiedRequest.timeoutInterval = TIMEOUT_LONGER
				reattemptedRequests.append(modifiedRequest)
			}
		}

		// using recursive could be considered, however, it's unnecessaril complication.
		fxdPrint("[\(#function)] \(reattemptedRequests.count)")
		for reattempted in reattemptedRequests {
			do {
				try await requesting(urlRequest: reattempted, reattemptedRequests:reattemptedRequests)
			}
			catch {
				fxdPrint("[\(#function)] reattempted: \(error)")
				throw error
			}
		}

		return safeDataAndResponse
	}
}
