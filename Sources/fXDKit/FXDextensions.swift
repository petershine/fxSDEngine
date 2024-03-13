

import Foundation
import UIKit


extension Date {
	public func formattedAgeText(since: Date = Date.init()) -> String? {

		let age = Int((since.timeIntervalSince1970) - timeIntervalSince1970)
		let days = Int(age/60/60/24)

		var ageText: String? = nil

		if days > 7 {
			ageText = description.components(separatedBy: " ").first
		}
		else if days > 0 && days <= 7 {
			ageText = "\(days) day"

			if (days > 1) {
				ageText = ageText! + "s"
			}
		}
		else {
			let seconds = age % 60
			let minutes = (age/60) % 60
			let hours = (age/60/60) % 24

			ageText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
		}

		return ageText
	}
}

extension Double {
	public func formattedDistanceText(format: String = "%0.1f") -> String? {
		var distanceText: String? = nil

		if self >= 1000.0 {
			distanceText = String(format: format + " km", self/1000.0)
		}
		else {
			distanceText = String(format: format + " m", self)
		}

		//TODO: use miles for US users

		return distanceText
	}
}

extension IndexPath {
	public var stringKey: String {
		return "\(row)_\(section)"
	}
}

extension String {
	public func sharableMessageWith(videoId: String?) -> String? {
		var formatted = self

		let videoPath = (videoId != nil && (videoId?.count)! > 0) ? "\(HOST_SHORT_YOUTUBE)\(videoId!)" : ""

		guard let swiftrange = formatted.range(of: HOST_SHORT_YOUTUBE) else {
			return "\(formatted) \(videoPath)".trimmingCharacters(in: .whitespacesAndNewlines)
		}


		var replacingRange = NSRange(swiftrange, in: formatted)
		replacingRange.length = videoPath.count //MARK: Assume every short url is same length
		if let swiftrange = Range(replacingRange, in: formatted) {
			formatted = formatted.replacingCharacters(in: swiftrange, with: videoPath).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		return formatted
	}

	public func sharableMessageWith(appConfig: FXDprotocolAppConfig) -> String? {
		var formatted = self

		let appendedLinkArray = [
			" via \(appConfig.homeURL)",
			" \(appConfig.homeURL)",

			" via \(appConfig.shortHomeURL)",
			" \(appConfig.shortHomeURL)",

			" via \(appConfig.twitterName)",
			" \(appConfig.twitterName)",
		]

		for appendedLink in appendedLinkArray {
			if formatted.count + appendedLink.count <= MAXIMUM_LENGTH_TWEET {
				formatted = formatted + appendedLink
				break
			}
		}

		return formatted
	}

	public func processedJSONData() -> Data? {
		var resultString = ""
		var isInQuotes = false
		var previousCharacter: Character?

		for character in self {
			switch character {
			case "\"":
				if previousCharacter != "\\" {
					isInQuotes = !isInQuotes
				}
				resultString.append(character)
			case "\n", "\r":
				if isInQuotes {
					resultString.append("\\n")
				} else {
					resultString.append(character)
				}
			default:
				resultString.append(character)
			}
			previousCharacter = character
		}

		return resultString.data(using: .utf8)
	}
}

extension Bundle {
	@objc public class func bundleVersion() -> String? {
		return self.main.infoDictionary?["CFBundleVersion"] as? String
	}

	@objc public class func bundleDisplayName() -> String? {
		return self.main.infoDictionary?["CFBundleDisplayName"] as? String
	}
}


@available(iOS 17.0, *)
extension UIAlertController {
	@objc public class func simpleAlert(withTitle title: String?, message: String?) {
		self.simpleAlert(withTitle: title,
						 message: message,
						 cancelText: nil,
						 fromScene: nil,
						 handler: nil)
	}

	@objc public class func simpleAlert(withTitle title: String?, message: String?,
								 cancelText: String?,
								 fromScene: UIViewController?,
								 handler: ((UIAlertAction) -> Swift.Void)?) {

		let alert = UIAlertController(title: title,
									  message: message,
									  preferredStyle: .alert)

		let cancelAction = UIAlertAction(title: ((cancelText != nil) ? cancelText! : NSLocalizedString("OK", comment: "")),
										 style: .cancel,
										 handler: handler)

		alert.addAction(cancelAction)


		var presentingScene: UIViewController? = fromScene

		if presentingScene == nil,
		   let mainWindow = UIApplication.shared.mainWindow(),
		   mainWindow.rootViewController != nil {
			presentingScene = mainWindow.rootViewController
		}

		DispatchQueue.main.async {
			presentingScene?.present(alert,
									 animated: true,
									 completion: nil)
		}
	}
}


@available(iOS 17.0, *)
extension UIApplication {
	@objc public func mainWindow() -> UIWindow? {
		return connectedScenes
			.flatMap {($0 as? UIWindowScene)?.windows ?? [] }
			.first {$0.isKeyWindow }
	}

	@objc public func openContactEmail(email: String) {
		let mailToPath = "mailto:\(email)"

		let displayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "(unknown bundlen name)"
		let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "(unknown bundle version)"

		var body: String = "\n\n\n\n\n_______________________________\n"
		body += "\(displayName) \(appVersion)\n"
		body += "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n"

		if let mailToURL = URL(string: mailToPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
			Self.shared.open(mailToURL, options: [:], completionHandler: nil)
		}
	}
}


extension UIDevice {
	@objc public class func machineNameCode() -> String? {
		/*
		struct utsname systemInfo;
		uname(&systemInfo);

		NSString *machineName = @(systemInfo.machine);
		*/

		var systemInfo = utsname()
		uname(&systemInfo)
		let machineNameCode = withUnsafePointer(to: &systemInfo.machine) {
			$0.withMemoryRebound(to: CChar.self, capacity: 1) {
				ptr in String.init(validatingUTF8: ptr)
			}
		}

		return machineNameCode
	}
}
