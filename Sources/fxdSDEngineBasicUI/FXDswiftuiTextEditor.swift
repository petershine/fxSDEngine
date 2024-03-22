

import SwiftUI


@available(iOS 17.0, *)
struct FXDTextEditorModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scrollContentBackground(.hidden)
			.background(.black)
			.foregroundStyle(.white)
			.cornerRadius(10.0)
			.overlay {
				RoundedRectangle(cornerRadius: 10.0)
					.stroke(Color.white, lineWidth:5.0)
			}
	}
}

@available(iOS 17.0, *)
public struct FXDswiftuiTextEditor: View {
	@Environment(\.dismiss) private var dismiss

	@FocusState private var focusedEditor: Int?
	@State private var editorsVStackHeight: CGFloat = 0.0

	@State private var editedParagraph_0: String = ""
	@State private var editedParagraph_1: String = ""
	@State private var editedText: String = ""

	var finishedEditing: ((String, String, String) -> Void)


	public init(editedText: String, finishedEditing: @escaping (String, String, String) -> Void) {
		self.editedText = editedText
		self.finishedEditing = finishedEditing
	}

	public var body: some View {
		ZStack {
			GeometryReader { outerGeometry in
				VStack {
					TextEditor(text: $editedParagraph_0)
						.frame(height: self.height(for: 0))
						.focused($focusedEditor, equals: 0)
						.modifier(FXDTextEditorModifier())

					TextEditor(text: $editedParagraph_1)
						.frame(height: self.height(for: 1))
						.focused($focusedEditor, equals: 1)
						.modifier(FXDTextEditorModifier())

					TextEditor(text: $editedText)
						.frame(height: self.height(for: 2))
						.focused($focusedEditor, equals: 2)
						.modifier(FXDTextEditorModifier())
				}
				.onAppear {
					editorsVStackHeight = outerGeometry.size.height
				}
				.onChange(of: outerGeometry.size.height) {
					(oldValue, newValue) in
					editorsVStackHeight = newValue
				}
				.animation(.easeInOut(duration: 0.2), value: focusedEditor)
			}


			VStack {
				Spacer()

				HStack {
					Spacer()

					FXDswiftuiButton(action: {
						finishedEditing(editedParagraph_0, editedParagraph_1, editedText)
						dismiss()
					}, systemImageName: "pencil.and.list.clipboard")
				}
			}
			.padding()
		}
		.onAppear {
			focusedEditor = 2
		}
	}


	private func height(for editorIndex: Int) -> CGFloat {
		if let focusedEditor = self.focusedEditor, 
			focusedEditor == editorIndex {
			return (editorsVStackHeight * 0.45)
		} else {
			return (editorsVStackHeight * 0.20)
		}
	}
}
