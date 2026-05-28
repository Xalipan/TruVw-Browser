import SwiftUI

struct AddressBarView: View {
    @ObservedObject var vm: BrowserViewModel
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    private var idleLabel: String {
        guard let url = vm.currentURL else { return "Search or Enter Website Name" }
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        // Single grouped capsule: [text field / label] [divider] [x or reload]
        HStack(spacing: 0) {
            if vm.isEditingAddress {
                // ── Editing: search field ────────────────────────────
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Search or Enter Website Name", text: $inputText)
                        .font(.system(size: 15))
                        .keyboardType(.webSearch)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.go)
                        .onSubmit { vm.navigate(to: inputText) }
                        .onAppear {
                            inputText = vm.currentURL?.absoluteString ?? ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isFocused = true
                            }
                        }
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)

                // Divider between field and cancel
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: 0.5, height: 18)

                // X cancel button
                Button {
                    vm.isEditingAddress = false
                    isFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }

            } else {
                // ── Idle: centered URL label ─────────────────────────
                Button {
                    vm.isEditingAddress = true
                } label: {
                    Text(idleLabel)
                        .font(.system(size: 15))
                        .foregroundColor(vm.currentURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.trailing, 4)

                // Divider between label and reload
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: 0.5, height: 18)

                // Reload / stop button
                Button {
                    vm.isLoading ? vm.stopLoading() : vm.reload()
                } label: {
                    Image(systemName: vm.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }
                .disabled(vm.currentURL == nil && !vm.isLoading)
            }
        }
        .frame(height: 36)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5))
        // Progress bar
        .overlay(alignment: .bottom) {
            if !vm.isEditingAddress && vm.isLoading && vm.estimatedProgress > 0 {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: geo.size.width * vm.estimatedProgress, height: 2)
                        .animation(.linear(duration: 0.08), value: vm.estimatedProgress)
                }
                .frame(height: 2)
                .clipShape(Capsule())
            }
        }
        .onChange(of: vm.isEditingAddress) { editing in
            if !editing { isFocused = false }
        }
    }
}
