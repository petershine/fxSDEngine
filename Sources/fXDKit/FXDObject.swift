

import Foundation


fileprivate var cancellablesKey: UInt8 = 0

@available(iOS 17.0, *)
extension NSObject {
	fileprivate var cancellables: [String : AnyCancellable?]? {
		get {
			return objc_getAssociatedObject(self, &cancellablesKey) as? [String : AnyCancellable?]
		}
		set {
			objc_setAssociatedObject(self, &cancellablesKey, newValue, .OBJC_ASSOCIATION_RETAIN)
		}
	}
}


import Combine

@available(iOS 17.0, *)
extension NSObject {
	public func publisherForDelayedAsyncTask(identifier: String? = nil, afterDelay: TimeInterval = 0.0, attachedTask: (() -> Void?)? = nil) -> AnyPublisher<String, Error> {
		return Future<String, Error> { promise in
			DispatchQueue.global().asyncAfter(deadline: .now() + afterDelay) {
				attachedTask?()
				promise(.success(".success: \(String(describing: self) + String(describing: identifier)) attachedTask: \(String(describing: attachedTask))"))
			}
		}
		.eraseToAnyPublisher()
	}

	public func cancellableForDelayedAsyncTask(identifier: String? = nil, afterDelay: TimeInterval = 0.0, attachedTask: (() -> Void?)? = nil, afterCompletion: (() -> Void?)? = nil) -> AnyCancellable {

		let publisher = publisherForDelayedAsyncTask(identifier: identifier, afterDelay: afterDelay, attachedTask: attachedTask)
		let cancellable = publisher
			.sink(receiveCompletion: {
				(completion) in

				switch completion {
					case .finished:
						fxdPrint(".finished: \(String(describing: identifier))")
						break

					case .failure(let error):
						fxdPrint(".failure: \(String(describing: identifier)) : \(error)")
				}

				afterCompletion?()

			}, receiveValue: { result in
				fxdPrint("promise: \(result)")
			})

		return cancellable
	}
}

@available(iOS 17.0, *)
extension NSObject {
	public func performAsyncTask(identifier: String = #function, afterDelay: TimeInterval = 0.0, attachedTask: (() -> Void?)?) {
		let extendedIdentifier = String(describing: self) + identifier

		let cancellable = cancellableForDelayedAsyncTask(identifier: identifier, afterDelay: afterDelay, attachedTask: attachedTask) {
			[weak self] in

			if var modified = self?.cancellables as? [String : AnyCancellable?] {
				modified[extendedIdentifier] = nil
				self?.cancellables = modified
			}
		}

		if cancellables == nil {
			cancellables = [String : AnyCancellable?]()
		}

		cancellables?[extendedIdentifier] = cancellable
	}

	public func cancelAsyncTask(identifier: String = #function) {
		let extendedIdentifier = String(describing: self) + identifier

		cancellables = cancellables?.filter({
			(key: String, value: AnyCancellable?) in
			if key == extendedIdentifier {
				value?.cancel()
				fxdPrint("cancel(): \(extendedIdentifier)")
			}
			return key != extendedIdentifier
		})
	}
}
