

import fXDKit
import fxSDEngine

import SwiftUI


public struct SDsceneBasicRoot: View {
	@Environment(\.colorScheme) var colorScheme

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
			FXDswiftuiMediaDisplay(displayedImage: sdObservable.displayedImage)

			if sdObservable.overlayObservable != nil {
				FXDswiftuiOverlay(observable: sdObservable.overlayObservable)
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.5)))
			}

			VStack {
				GROUP_resetting
					.padding()

				Spacer()

				HStack {
					if sdObservable.isJobRunning {
						GROUP_progress
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
					}
					else {
						GROUP_saving
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))

						Spacer()

						GROUP_generating
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
					}

					Spacer()

					if !sdObservable.isJobRunning {
						GROUP_editor
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
					}
				}
				.padding()
			}

			if shouldPresentPromptEditor {
				OVERLAY_promptEditor
			}
		}
	}
}


extension SDsceneBasicRoot {
	var GROUP_resetting: some View {
		HStack {
			VStack {
				if sdObservable.isJobRunning {
					FXDswiftuiButton(
						systemImageName: "stop.circle",
						foregroundStyle: .red,
						action: {
							sdEngine.interrupt{
								(error) in

								Task {
									sdObservable.shouldContinueRefreshing = false

									UIAlertController.errorAlert(error: error, title: "Interrupted")
								}
							}
						})
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
				}
			}

			Spacer()

			VStack {
				if !sdObservable.isJobRunning {
					FXDswiftuiButton(
						systemImageName: "arrow.clockwise",
						foregroundStyle: .white,
						action: {
							sdEngine.refresh_LastPayload(completionHandler: nil)
						})
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
				}
			}
		}
	}

	var GROUP_progress: some View {
		VStack(
			alignment: .leading,
			spacing: nil,
			content: {

				Spacer()

				HStack {
					FXDswiftuiButton(
						systemImageName: (sdObservable.shouldContinueRefreshing ? "tv.slash" : "tv"),
						foregroundStyle: .white,
						action: {
							sdObservable.shouldContinueRefreshing.toggle()
							sdEngine.continuousProgressRefreshing()
						})
					.padding()

					if sdObservable.shouldContinueRefreshing {
						if let progress = sdObservable.progressValue {
							Text(String(format: "%0.1f %%", progress * 100.0))
								.multilineTextAlignment(.leading)
								.foregroundStyle(.white)
						}
					}
				}
			})
	}

	var GROUP_saving: some View {
		VStack {
			Spacer()

			FXDswiftuiButton(
				systemImageName: "square.and.arrow.down",
				foregroundStyle: .white,
				action: {
					if let availableImage = sdObservable.displayedImage {
						UIActivityViewController.show(items: [availableImage])
					}
				})
		}
	}

	var GROUP_generating: some View {
		VStack {
			Spacer()

			FXDswiftuiButton(
				systemImageName: "paintbrush",
				foregroundStyle: .white,
				action: {
					sdObservable.shouldContinueRefreshing = true
					sdEngine.continuousProgressRefreshing()

					sdEngine.execute_txt2img {
						error in

						Task {
							sdObservable.shouldContinueRefreshing = false
						}
					}
				})
		}
	}

	var GROUP_editor: some View {
		VStack {
			Spacer()

			FXDswiftuiButton(
				systemImageName: "lightbulb",
				foregroundStyle: .white,
				action: {
					shouldPresentPromptEditor = true
				})
		}
	}
}


extension SDsceneBasicRoot {
	@ViewBuilder
	var OVERLAY_promptEditor: some View {
		let prompt = sdEngine.currentGenerationPayload?.prompt ?? "PROMPT"
		let negative_prompt = sdEngine.currentGenerationPayload?.negative_prompt ?? "NEGATIVE_PROMPT"

		FXDswiftuiTextEditor(
			shouldPresentPromptEditor: $shouldPresentPromptEditor,
			editedParagraph_0: prompt,
			editedParagraph_1: negative_prompt,
			finishedEditing: {
				(editedPrompt, editedNegativePrompt) in

				if let modifiedPayload = sdEngine.currentGenerationPayload?.modified(
					editedPrompt: editedPrompt,
					editedNegativePrompt: editedNegativePrompt) {

					fxd_log()
					sdEngine.currentGenerationPayload = modifiedPayload
				}
			})
		.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
		.onDisappear(perform: {
			shouldPresentPromptEditor = false
		})
	}
}

