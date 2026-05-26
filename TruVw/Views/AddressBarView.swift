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
        HStack(spacing: 8) {
            ZStack {
                // ── Idle pill ────────────────────────────────────────
                if !vm.isEditingAddress {
                    Button {
                        inputText = vm.currentURL?.absoluteString ?? ""
                        vm.isEditingAddress = true
                        isFocused = true
                    } label: {
                        HStack(spacing: 5) {
                            if let url = vm.currentURL {
                                Image(systemName: url.scheme == "https" ? "lock.fill" : "lock.open.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(url.scheme == "https" ? Color(.secondaryLabel) : .orange)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            Text(idleLabel)
                                .font(.system(size: 15))
                                .foregroundColor(vm.currentURL == nil ? Color(.secondaryLabel) : Color(.label))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                if vm.isLoading { vm.stopLoading() } else { vm.reload() }
                            } label: {
                                Image(systemName: vm.isLoading ? "xmark" : "arrow.clockwise")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            .disabled(vm.currentURL == nil && !vm.isLoading)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(9)
                        .overlay(alignment: .bottom) {
                            if vm.isLoading && vm.estimatedProgress > 0 {
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.5))
                                        .frame(width: geo.size.width * vm.estimatedProgress, height: 2)
                                        .animation(.linear(duration: 0.08), value: vm.estimatedProgress)
                                }
                                .frame(height: 2)
                                .cornerRadius(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                // ── Edit field ───────────────────────────────────────
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.secondaryLabel))
                        TextField("Search or Enter Website Name", text: $inputText)
                            .font(.system(size: 15))
                            .keyboardType(.webSearch)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .submitLabel(.go)
                            .onSubmit { vm.navigate(to: inputText) }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isFocused = true
                                }
                            }
                        if !inputText.isEmpty {
                            Button { inputText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(.tertiaryLabel))
                                    .font(.system(size: 15))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(9)
                }
            }
            .frame(maxWidth: .infinity)

            // Cancel button slides in when editing
            if vm.isEditingAddress {
                Button("Cancel") {
                    vm.isEditingAddress = false
                    isFocused = false
                }
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isEditingAddress)
        .onChange(of: vm.isEditingAddress) { editing in
            if !editing { isFocused = false }
        }
    }
}

