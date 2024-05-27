

import fXDKit
import fxSDEngine

import SwiftUI


public struct FXDswiftuiSDEngineBasicRoot: View {
	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@Environment(\.verticalSizeClass) var verticalSizeClass

	@State var shouldPresentPromptEditor: Bool = false

	var sdEngine: FXDmoduleSDEngine


	public init(sdEngine: FXDmoduleSDEngine?) {
		self.sdEngine = sdEngine ?? FXDmoduleSDEngine()
	}

	public var body: some View {
		ZStack {
			FXDswiftuiMediaDisplay(mediaImage: sdEngine.observable.generatedImage)

			VStack {
				Spacer()

				HStack {
					VStack {
						Spacer()

						FXDswiftuiButton(
							systemImageName: "xmark",
							foregroundStyle: .red,
							action: {
								sdEngine.interrupt{
									error in

									Task {	@MainActor in
										sdEngine.observable.shouldContinueRefreshing = false

										let localizedDescription = error?.localizedDescription ?? "Interrupted"
										UIAlertController.simpleAlert(withTitle: localizedDescription, message: nil)
									}
								}
							})
					}

					Spacer()

					VStack {
						Spacer()

						if sdEngine.observable.shouldContinueRefreshing {
							Text("\(sdEngine.observable.generationProgress)")
								.padding()
						}

						FXDswiftuiButton(
							systemImageName: (sdEngine.observable.shouldContinueRefreshing ? "pause.fill" : "play.fill"),
							action: {
								sdEngine.observable.shouldContinueRefreshing.toggle()
								sdEngine.continuousProgressRefreshing()
							})
						.padding()
					}

					Spacer()

					VStack {
						Spacer()

						FXDswiftuiButton(
							systemImageName: "lightbulb",
							action: {
								shouldPresentPromptEditor = true
							})
						.padding()

						FXDswiftuiButton(
							systemImageName: "paintbrush",
							action: {
								sdEngine.observable.shouldContinueRefreshing = true
								sdEngine.continuousProgressRefreshing()

								sdEngine.execute_txt2img {
									error in

									sdEngine.observable.shouldContinueRefreshing = false
								}
							})
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

