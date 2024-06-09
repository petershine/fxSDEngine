

import SwiftUI

import fxSDEngine
import fXDKit


public struct FXDsceneBasicRoot: View {
	@Environment(\.colorScheme) var colorScheme

	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@Environment(\.verticalSizeClass) var verticalSizeClass

	@State var shouldPresentPromptEditor: Bool = false

	var sdEngine: FXDmoduleMain
	@ObservedObject private var sdObservable: FXDobservableMain


	public init(sdEngine: SDmoduleMain) {
		self.sdEngine = sdEngine as! FXDmoduleMain
		self.sdObservable = sdEngine.observable as! FXDobservableMain
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
					let isJobRunning = sdObservable.progressObservable?.state?.isJobRunning() ?? false
					if !isJobRunning {
						GROUP_saving
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))

						Spacer()

						GROUP_generating
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
					}

					Spacer()

					if !isJobRunning {
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


extension FXDsceneBasicRoot {
	var GROUP_resetting: some View {
		HStack {
			HStack {
				let isJobRunning = sdObservable.progressObservable?.state?.isJobRunning() ?? false
				let shouldContinueRefreshing = sdObservable.shouldContinueRefreshing
				if isJobRunning || shouldContinueRefreshing {
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

					if let progress = sdObservable.progressObservable?.progress {
						Text(String(format: "%0.1f %%", progress * 100.0))
							.multilineTextAlignment(.leading)
							.foregroundStyle(.white)
					}

					if let job = sdObservable.progressObservable?.state?.job {
						Text(job)
							.multilineTextAlignment(.leading)
							.foregroundStyle(.white)
					}
				}
			}

			Spacer()

			VStack {
				let isJobRunning = sdObservable.progressObservable?.state?.isJobRunning() ?? false
				if !isJobRunning {
					FXDswiftuiButton(
						systemImageName: "arrow.clockwise",
						foregroundStyle: .white,
						action: {
							sdEngine.refresh_sysInfo(completionHandler: nil)
						})
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
				}
			}
		}
	}

	var GROUP_saving: some View {
		VStack {
			Spacer()

			FXDswiftuiButton(
				systemImageName: "square.and.arrow.down",
				foregroundStyle: .white,
				action: {
					if let pngItem = sdEngine.sharableItem {
						UIActivityViewController.show(items: [pngItem])
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
				systemImageName: "pencil.and.list.clipboard",
				foregroundStyle: .white,
				action: {
					shouldPresentPromptEditor = true
				})
		}
	}
}


extension FXDsceneBasicRoot {
	@ViewBuilder
	var OVERLAY_promptEditor: some View {
		let prompt = sdEngine.generationPayload?.prompt ?? "PROMPT"
		let negative_prompt = sdEngine.generationPayload?.negative_prompt ?? "NEGATIVE_PROMPT"

		FXDswiftuiTextEditor(
			shouldPresentPromptEditor: $shouldPresentPromptEditor,
			editedParagraph_0: prompt,
			editedParagraph_1: negative_prompt,
			finishedEditing: {
				(editedPrompt, editedNegativePrompt) in

				if let modifiedPayload = sdEngine.generationPayload?.modified(
					editedPrompt: editedPrompt,
					editedNegativePrompt: editedNegativePrompt) {

					fxd_log()
					sdEngine.generationPayload = modifiedPayload
				}
			})
		.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
		.onDisappear(perform: {
			shouldPresentPromptEditor = false
		})
	}
}

