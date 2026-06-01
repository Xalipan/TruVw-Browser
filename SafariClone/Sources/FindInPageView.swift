import SwiftUI
import WebKit

struct FindInPageView: View {
    @ObservedObject var viewModel: WebViewModel
    @Binding var isVisible: Bool
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    TextField("Find on Page", text: $query)
                        .focused($focused)
                        .onSubmit { findNext() }
                        .onChange(of: query) { newValue in
                            viewModel.findInPage(query: newValue)
                        }

                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(.systemGray3))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5)))

                HStack(spacing: 2) {
                    Button { findPrev() } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(query.isEmpty)

                    Button { findNext() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(query.isEmpty)
                }

                Button("Done") {
                    focused = false
                    withAnimation { isVisible = false }
                    viewModel.findInPage(query: "")
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focused = true }
        }
    }

    private func findNext() {
        viewModel.findNext(query: query)
    }

    private func findPrev() {
        viewModel.findPrevious(query: query)
    }
}
