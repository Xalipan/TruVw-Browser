import SwiftUI

struct AddressBarView: View {
    var viewModel: WebViewModel?
    @Binding var isExpanded: Bool
    @Binding var urlBarFocused: Bool

    @State private var inputText: String = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    if !isEditing {
                        securityIndicator
                    }

                    TextField("Search or enter website name", text: $inputText)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focused)
                        .onSubmit {
                            submitURL()
                        }
                        .onChange(of: focused) { newValue in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isEditing = newValue
                            }
                            if newValue {
                                inputText = viewModel?.urlString ?? ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                }
                            }
                        }

                    if isEditing && !inputText.isEmpty {
                        Button {
                            inputText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(.systemGray3))
                                .font(.system(size: 16))
                        }
                    } else if let vm = viewModel {
                        if vm.isLoading {
                            Button { vm.stopLoading() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        } else if !vm.urlString.isEmpty {
                            Button { vm.reload() } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                )

                if isEditing {
                    Button("Cancel") {
                        focused = false
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded = false
                            urlBarFocused = false
                        }
                    }
                    .foregroundColor(.blue)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            if isEditing && !inputText.isEmpty {
                SearchSuggestionsView(query: inputText) { selected in
                    inputText = selected
                    submitURL()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            inputText = viewModel?.urlString ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focused = true
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isEditing)
    }

    private var securityIndicator: some View {
        Group {
            if let urlStr = viewModel?.urlString, urlStr.hasPrefix("https://") {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            } else if viewModel?.urlString.hasPrefix("http://") == true {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
    }

    private func submitURL() {
        focused = false
        viewModel?.load(urlString: inputText)
        withAnimation(.spring(response: 0.3)) {
            isExpanded = false
            urlBarFocused = false
        }
    }
}

// MARK: - Search Suggestions

struct SearchSuggestionsView: View {
    let query: String
    let onSelect: (String) -> Void

    private var suggestions: [String] {
        var results: [String] = []
        if query.contains(".") && !query.contains(" ") {
            results.append("https://\(query)")
        }
        results.append("https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        results.append("https://duckduckgo.com/?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        results.append("https://www.bing.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: suggestionIcon(for: suggestion))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
                Divider().padding(.leading, 48)
            }
        }
        .background(Color(.systemBackground))
    }

    private func suggestionIcon(for suggestion: String) -> String {
        if suggestion.hasPrefix("https://") && !suggestion.contains("search?q=") && !suggestion.contains("/?q=") {
            return "globe"
        }
        return "magnifyingglass"
    }
}
