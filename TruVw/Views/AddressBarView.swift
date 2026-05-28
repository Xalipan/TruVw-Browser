import SwiftUI

struct AddressBarView: View {
    @ObservedObject var vm: BrowserViewModel
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    // Shows cleaned host in idle mode (no www., no scheme)
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
                        HStack(spacing: 0) {
                            // Centered label — no lock icon (no reader-mode clutter)
                            Text(idleLabel)
                                .font(.system(size: 15))
                                .foregroundColor(
                                    vm.currentURL == nil
                                        ? Color(.secondaryLabel)
                                        : Color(.label)
                                )
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                        // Progress bar at the bottom of the capsule
                        .overlay(alignment: .bottom) {
                            if vm.isLoading && vm.estimatedProgress > 0 {
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.blue.opacity(0.55))
                                        .frame(
                                            width: geo.size.width * vm.estimatedProgress,
                                            height: 3
                                        )
                                        .animation(
                                            .linear(duration: 0.08),
                                            value: vm.estimatedProgress
                                        )
                                }
                                .frame(height: 3)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)

                // ── Edit field ───────────────────────────────────────
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
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
                                // Small delay lets the focus system settle
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
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.blue.opacity(0.5), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity)

            // Cancel slides in when editing
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
