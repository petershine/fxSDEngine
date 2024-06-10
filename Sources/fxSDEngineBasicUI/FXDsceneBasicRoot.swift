

import SwiftUI

import fxSDEngine
import fXDKit


public struct FXDsceneBasicRoot: View {
	@Environment(\.colorScheme) var colorScheme

	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@Environment(\.verticalSizeClass) var verticalSizeClass

	@State var shouldPresentPromptEditor: Bool = false

	@ObservedObject var sdEngine: FXDmoduleBasic

	@State var batchCount: Double = 1.0


	public init(sdEngine: FXDmoduleBasic) {
		self.sdEngine = sdEngine

		self.batchCount = Double(sdEngine.generationPayload?.n_iter ?? 1)
	}

	public var body: some View {
		ZStack {
			FXDswiftuiMediaDisplay(
				displayedImage: Binding.constant(sdEngine.displayedImage),
				contentMode: Binding.constant(.fit)
			)

			if sdEngine.overlayObservable != nil {
				FXDswiftuiOverlay(observable: sdEngine.overlayObservable)
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.5)))
			}

			VStack {
				GROUP_resetting
					.padding()
				
				Spacer()
				
				let isJobRunning = sdEngine.progressObservable?.state?.isJobRunning() ?? false
				if !isJobRunning {
					HStack {
						GROUP_saving
						
						Spacer()
						
						GROUP_generating
						
						Spacer()
						
						GROUP_editor
					}
					.padding()
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
				}
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
				let isJobRunning = sdEngine.progressObservable?.state?.isJobRunning() ?? false
				let shouldContinueRefreshing = sdEngine.shouldContinueRefreshing
				if isJobRunning || shouldContinueRefreshing {
					FXDswiftuiButton(
						systemImageName: "stop.circle",
						foregroundStyle: .red,
						action: {
							sdEngine.interrupt{
								(error) in

								Task {
									sdEngine.shouldContinueRefreshing = false

									UIAlertController.errorAlert(error: error, title: "Interrupted")
								}
							}
						})
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))

					if let progress = sdEngine.progressObservable?.progress {
						Text(String(format: "%0.1f %%", progress * 100.0))
							.multilineTextAlignment(.leading)
							.foregroundStyle(.white)
					}

					if let job = sdEngine.progressObservable?.state?.job {
						Text(job)
							.multilineTextAlignment(.leading)
							.foregroundStyle(.white)
					}
				}
			}

			Spacer()

			VStack {
				let isJobRunning = sdEngine.progressObservable?.state?.isJobRunning() ?? false
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
					sdEngine.shouldContinueRefreshing = true
					sdEngine.continuousProgressRefreshing()

					sdEngine.execute_txt2img {
						error in

						Task {
							sdEngine.shouldContinueRefreshing = false
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
					editedNegativePrompt: editedNegativePrompt,
					batchCount: batchCount) {

					fxd_log()
					sdEngine.generationPayload = modifiedPayload
				}
			},
			attachedView: {
				FXDsceneBasicConfiguration(batchCount: $batchCount)
					.foregroundStyle(.white)
			})
		.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
		.onDisappear(perform: {
			shouldPresentPromptEditor = false
		})
	}
}

