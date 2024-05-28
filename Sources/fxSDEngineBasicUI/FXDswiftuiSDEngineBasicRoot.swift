

import fXDKit
import fxSDEngine

import SwiftUI


public struct FXDswiftuiSDEngineBasicRoot: View {
	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@Environment(\.verticalSizeClass) var verticalSizeClass

	@State var shouldPresentPromptEditor: Bool = false

	var sdEngine: FXDmoduleSDEngine
	@ObservedObject private var sdObservable: FXDobservableSDProperties


	public init(sdEngine: FXDmoduleSDEngine?) {
		self.sdEngine = sdEngine ?? FXDmoduleSDEngine()
		self.sdObservable = self.sdEngine.observable
	}

	public var body: some View {
		ZStack {
			FXDswiftuiMediaDisplay(mediaImage: sdObservable.generatedImage)

			VStack {
				HStack {
					VStack {
						FXDswiftuiButton(
							systemImageName: "arrow.clockwise",
							foregroundStyle: .white,
							action: {
								sdEngine.refresh_LastPayload(completionHandler: nil)
						})
					}
					Spacer()
				}


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
										sdObservable.shouldContinueRefreshing = false

										let localizedDescription = error?.localizedDescription ?? "Interrupted"
										UIAlertController.simpleAlert(withTitle: localizedDescription, message: nil)
									}
								}
							})
					}

					Spacer()

					VStack {
						Spacer()

						if sdObservable.shouldContinueRefreshing {
							Text("\(sdObservable.generationProgress)")
								.padding()
						}

						FXDswiftuiButton(
							systemImageName: (sdObservable.shouldContinueRefreshing ? "pause.fill" : "play.fill"),
							foregroundStyle: .white,
							action: {
								sdObservable.shouldContinueRefreshing.toggle()
								sdEngine.continuousProgressRefreshing()
							})
						.padding()
					}

					Spacer()

					VStack {
						Spacer()

						FXDswiftuiButton(
							systemImageName: "lightbulb",
							foregroundStyle: .white,
							action: {
								shouldPresentPromptEditor = true
							})
						.padding()

						FXDswiftuiButton(
							systemImageName: "paintbrush",
							foregroundStyle: .white,
							action: {
								sdObservable.shouldContinueRefreshing = true
								sdEngine.continuousProgressRefreshing()

								sdEngine.execute_txt2img {
									error in

									sdObservable.shouldContinueRefreshing = false
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
				})
			.transition(AnyTransition.opacity.animation(.easeInOut(duration: 1.0)))
			.onDisappear(perform: {
				shouldPresentPromptEditor = false
			})
		}
	}
}

