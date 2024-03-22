

import SwiftUI


let touchableDimension: CGFloat = 50.0


@available(iOS 17.0, *)
struct FXDButtonModifier: ViewModifier {
	var frame: CGRect = CGRect(x: 0.0, y: 0.0, width: touchableDimension, height: touchableDimension)
	var backgroundColor: Color = .white
	var foregroundColor: Color = .black
	var cornerRadius: CGFloat = (touchableDimension/5.0)

	func body(content: Content) -> some View {
		content
			.frame(width: frame.size.width, height: frame.size.height)
			.background(backgroundColor)
			.foregroundColor(foregroundColor)
			.cornerRadius(cornerRadius)
			.overlay {
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(Color.black, lineWidth: (cornerRadius/2.0))
			}
	}
}


@available(iOS 17.0, *)
public struct FXDswiftuiButton: View {
	var action: () -> Void
	var systemImageName: String

	public init(action: @escaping () -> Void, systemImageName: String) {
		self.action = action
		self.systemImageName = systemImageName
	}
	
	public var body: some View {
		Button(action: action) {
			Image(systemName: systemImageName)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.padding(5.0)
		}
		.modifier(FXDButtonModifier())
	}
}
