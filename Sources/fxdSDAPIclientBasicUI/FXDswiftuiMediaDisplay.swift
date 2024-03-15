

import SwiftUI

import fXDKit


@available(iOS 17.0, *)
struct FXDswiftuiMediaDisplay: View {
	@Binding var mediaImage: UIImage?

    var body: some View {
		Color.black
			.overlay {
				if let availableImage = mediaImage {
					Image(uiImage: availableImage)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.gesture(
							LongPressGesture().onEnded { _ in
								if let availableImage = mediaImage {
									showActivitySheet(items: [availableImage])
								}
							})
				}
			}
			.ignoresSafeArea()
    }

	private func showActivitySheet(items: [Any]) {
		guard let rootViewController = UIApplication.shared.mainWindow()?.rootViewController else {
			return
		}


		let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
		if let popoverController = activityController.popoverPresentationController {
			let sourceRectCenter = CGPoint(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY)
			
			popoverController.sourceView = rootViewController.view
			popoverController.sourceRect = CGRect(origin: sourceRectCenter, size: CGSize(width: 1, height: 1))
			popoverController.permittedArrowDirections = []
		}
		
		rootViewController.present(activityController, animated: true)
	}
}


@available(iOS 17.0, *)
#Preview {
	FXDswiftuiMediaDisplay(mediaImage: Binding.constant(UIImage()))
}
