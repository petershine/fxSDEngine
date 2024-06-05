

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
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.25)))
					}

					Spacer()

					if !sdObservable.isJobRunning {
						GROUP_generating
							.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.25)))
					}
				}
				.padding()
			}
		}
		.fullScreenCover(isPresented: $shouldPresentPromptEditor) {
			OVERLAY_promptEditor
		}
	}
}


extension SDsceneBasicRoot {
	var GROUP_resetting: some View {
		HStack {
			VStack {
				if sdObservable.isJobRunning {
					FXDswiftuiButton(
						systemImageName: "xmark",
						foregroundStyle: .red,
						action: {
							sdEngine.interrupt{
								(error) in

								Task {	@MainActor in
									sdObservable.shouldContinueRefreshing = false

									UIAlertController.errorAlert(error: error, title: "Interrupted")
								}
							}
						})
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.25)))
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
					.transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.25)))
				}
			}
		}
	}

	var GROUP_progress: some View {
		VStack(alignment: .leading,
			   spacing: nil,
			   content: {
			
			Spacer()

			if sdObservable.shouldContinueRefreshing,
			   let progress = sdObservable.progressValue {
				Text(String(format: "%0.1f %%", progress * 100.0))
					.multilineTextAlignment(.leading)
					.foregroundStyle(.white)
			}

			FXDswiftuiButton(
				systemImageName: (sdObservable.shouldContinueRefreshing ? "tv.slash" : "tv"),
				foregroundStyle: .white,
				action: {
					sdObservable.shouldContinueRefreshing.toggle()
					sdEngine.continuousProgressRefreshing()
				})
		})
	}

	var GROUP_generating: some View {
		VStack {
			Spacer()

			FXDswiftuiButton(
				systemImageName: "lightbulb",
				foregroundStyle: .white,
				action: {
					shouldPresentPromptEditor = true
				})
			.padding(.bottom)

			FXDswiftuiButton(
				systemImageName: "paintbrush",
				foregroundStyle: .white,
				action: {
					sdObservable.shouldContinueRefreshing = true
					sdEngine.continuousProgressRefreshing()

					sdEngine.execute_txt2img {
						error in

						Task {	@MainActor in
							sdObservable.shouldContinueRefreshing = false
						}
					}
				})
		}
	}
}


extension SDsceneBasicRoot {
	@ViewBuilder
	var OVERLAY_promptEditor: some View {
		FXDswiftuiTextEditor(
			editedText: "",
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

