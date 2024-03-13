

import SwiftUI
import Foundation


@available(iOS 17.0, *)
public struct FXDProgressBar: View {
	fileprivate var maxValue: CGFloat = 1.0
	fileprivate var barHeight: CGFloat = 4.0

	@Binding var value: CGFloat


	init(value: Binding<CGFloat>) {
		_value = value
	}

	public var body: some View {
		ZStack {
			GeometryReader{ proxy in
				Capsule()
					.fill(.secondary)

				Capsule()
					.fill(.tint)
					.frame(width: proxy.size.width * (value / maxValue), 
						   height: proxy.size.height,
						   alignment: .leading)
			}
		}
		.frame(height: barHeight)
	}
}
