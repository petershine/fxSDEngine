

import SwiftUI

import fxSDEngine
import fXDKit


struct FXDsceneBasicConfiguration: View {
	@Binding var batchCount: Double

    var body: some View {
		HStack {
			Text("BATCH COUNT: \(batchCount)")
			Slider(value: $batchCount, in: 1...100, step: 1)
		}
    }
}
