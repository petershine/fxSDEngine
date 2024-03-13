

import SwiftUI


@available(iOS 17.0, *)
open class FXDconfigurationInformation: ObservableObject {
	@Published open var shouldDismiss: Bool = false

	@Published open var overlayColor: UIColor? = nil
	@Published open var shouldIgnoreUserInteraction: Bool

	@Published open var informationTitle: String = ""
	@Published open var message_0: String = ""
	@Published open var message_1: String = ""

	@Published open var sliderValue: CGFloat
	@Published open var sliderTint: Color? = nil

	var cancellableTask: Task<Void, Error>? = nil

	public init(overlayColor: UIColor? = nil, 
				shouldIgnoreUserInteraction: Bool? = false,
				
				sliderValue: CGFloat? = nil,
				sliderTint: Color? = nil) {

		self.overlayColor = overlayColor
		self.shouldIgnoreUserInteraction = shouldIgnoreUserInteraction ?? false
		
		self.sliderValue = sliderValue ?? 0.0
		self.sliderTint = sliderTint ?? Color(uiColor: .systemBlue)
	}
}

@available(iOS 17.0, *)
public struct FXDswiftuiInformation: View {
	@Environment(\.dismiss) var dismiss
	@Environment(\.colorScheme) var colorScheme
	
	@ObservedObject var configuration: FXDconfigurationInformation


	public init(configuration: FXDconfigurationInformation = FXDconfigurationInformation()) {
		self.configuration = configuration
	}

    public var body: some View {
		VStack {
			Text(configuration.informationTitle)
				.font(.title)
				.fontWeight(.bold)

			Text(configuration.message_0)

			ProgressView()
				.controlSize(.large)
				.frame(alignment: .center)

			FXDProgressBar(value: $configuration.sliderValue)
				.tint(configuration.sliderTint)
				.opacity(configuration.sliderValue > 0.0 ? 1.0 : 0.0)
				.allowsHitTesting(false)
				.padding()

			Text(configuration.message_1)
		}
		.ignoresSafeArea(.all)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding([.leading, .trailing])
		.contentShape(Rectangle())
		.presentationBackground(
			Color(uiColor: configuration.overlayColor ?? (colorScheme == .dark ? .black : .white))
				.opacity(0.75)
		)
		.allowsHitTesting(!configuration.shouldIgnoreUserInteraction)
		.onTapGesture {
			configuration.shouldDismiss = true
			configuration.cancellableTask?.cancel()
		}
		.onChange(of: configuration.shouldDismiss) {
			if configuration.shouldDismiss {
				dismiss()
			}
		}
    }
}


import Combine

@available(iOS 17.0, *)
public class FXDhostedInformation: UIHostingController<FXDswiftuiInformation> {
	fileprivate var observedCancellable: AnyCancellable? = nil

	override public func didMove(toParent parent: UIViewController?) {
		super.didMove(toParent: parent)

		guard parent != nil else {
			return
		}


		self.view.frame.size = parent!.view.frame.size
		self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
	}

	override public func viewDidLoad() {
		super.viewDidLoad()

		let reactToTraitChanges = {
			[weak self] in

			let interfaceStyle = self?.traitCollection.userInterfaceStyle

			self?.view.backgroundColor = self?.rootView.configuration.overlayColor ?? (interfaceStyle == .dark ? UIColor.black : UIColor.white).withAlphaComponent(0.75)
		}

		reactToTraitChanges()

		registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
			(self: Self, previousTraitCollection: UITraitCollection) in

			reactToTraitChanges()
		}


		self.observedCancellable = self.rootView.configuration.$shouldDismiss.sink(receiveValue: {
			[weak self] (shouldDismiss) in

			if shouldDismiss {
				UIApplication.shared.mainWindow()?.hideWaitingView(afterDelay: DURATION_QUARTER)
			}

			self?.observedCancellable = nil
		})
	}
}



// Example usage
@available(iOS 17.0, *)
extension FXDconfigurationInformation {
	public class func exampleCountingUp() -> FXDconfigurationInformation {

		let testingConfiguration = FXDconfigurationInformation(
			shouldIgnoreUserInteraction: false,
			sliderValue: 0.0)


		let taskInterval = 1.0
		Task {
			for step in 0...10 {
				//Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates.

				DispatchQueue.main.async {
					testingConfiguration.sliderValue = CGFloat(step) * 0.1
				}

				do {
					try await Task.sleep(nanoseconds: UInt64((taskInterval * 1_000_000_000).rounded()))
				}
			}

			DispatchQueue.main.async {
				testingConfiguration.shouldDismiss = true
			}
		}

		return testingConfiguration
	}
}

