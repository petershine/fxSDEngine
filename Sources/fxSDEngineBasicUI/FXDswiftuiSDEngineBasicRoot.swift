

import fXDKit
import fxSDEngine

import SwiftUI


public struct FXDswiftuiSDEngineBasicRoot: View {
	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@Environment(\.verticalSizeClass) var verticalSizeClass

	@State var shouldPresentPromptEditor: Bool = false

	@ObservedObject var sdEngine: FXDmoduleSDEngine


	public init(sdEngine: FXDmoduleSDEngine? = nil) {
		self.sdEngine = sdEngine ?? FXDmoduleSDEngine()
	}

	public var body: some View {
		ZStack {
			FXDswiftuiMediaDisplay(mediaImage: sdEngine.generatedImage)

			VStack {
				Spacer()

				HStack {
					VStack {
						FXDswiftuiButton(action: {
							sdEngine.shouldContinueRefreshing.toggle()
							sdEngine.continuousProgressRefreshing()
						}, systemImageName: (sdEngine.shouldContinueRefreshing ? "pause.fill" : "play.fill"))
						.padding()

						if sdEngine.shouldContinueRefreshing {
							Text("\(sdEngine.generationProgress)")
						}
					}

					Spacer()

					VStack {
						FXDswiftuiButton(action: {
							shouldPresentPromptEditor = true
						}, systemImageName: "lightbulb")
						.padding()

						FXDswiftuiButton(action: {
							sdEngine.execute_txt2img(completionHandler: nil)
						}, systemImageName: "paintbrush")
					}
				}
			}
			.padding()
		}
		.fullScreenCover(isPresented: $shouldPresentPromptEditor) {
			promptEditor()
		}
	}
}


extension FXDswiftuiSDEngineBasicRoot {
	@ViewBuilder
	func promptEditor() -> some View {
		if let currentPayload = sdEngine.currentPayload,
		   let payload = String(data: currentPayload, encoding: .utf8) {

			FXDswiftuiTextEditor(
				editedText: payload,
				finishedEditing: {
					(editedParagraph_0, editedParagraph_1, editedPayload) in
					fxdPrint("editedParagraph_0: \(editedParagraph_0)")
					fxdPrint("editedParagraph_1: \(editedParagraph_1)")

					sdEngine.savePayloadToFile(payload: payload)
				})
			.transition(AnyTransition.opacity.animation(.easeInOut(duration: 1.0)))
			.onDisappear(perform: {
				shouldPresentPromptEditor = false
			})
		}
	}
}

