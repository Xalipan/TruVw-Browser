import SwiftUI
import WebKit

struct JSConsoleView: View {
    @ObservedObject var viewModel: WebViewModel
    @Environment(\.dismiss) var dismiss

    @State private var inputText = ""
    @State private var messages: [ConsoleEntry] = []
    @State private var filter: ConsoleLevel? = nil
    @FocusState private var focused: Bool
    @State private var autoscroll = true

    var filteredMessages: [ConsoleEntry] {
        guard let filter = filter else { return messages }
        return messages.filter { $0.level == filter }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredMessages) { msg in
                                ConsoleMessageRow(entry: msg)
                                    .id(msg.id)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                    }
                    .onChange(of: messages.count) { _ in
                        if autoscroll {
                            withAnimation { proxy.scrollTo("bottom") }
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("JavaScript expression...", text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .focused($focused)
                        .onSubmit { executeInput() }
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button {
                        executeInput()
                    } label: {
                        Image(systemName: "return")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            .navigationTitle("JS Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button {
                            messages.removeAll()
                        } label: {
                            Image(systemName: "trash")
                        }
                        Toggle("Auto", isOn: $autoscroll)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .consoleLog)) { notification in
                if let level = notification.userInfo?["level"] as? String,
                   let message = notification.userInfo?["message"] as? String {
                    let entry = ConsoleEntry(
                        level: ConsoleLevel(rawValue: level) ?? .log,
                        text: message,
                        timestamp: Date()
                    )
                    DispatchQueue.main.async {
                        messages.append(entry)
                        if messages.count > 2000 { messages.removeFirst(messages.count - 2000) }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            filterButton(nil, label: "All")
            filterButton(.log, label: "Log")
            filterButton(.warn, label: "Warn")
            filterButton(.error, label: "Error")
            filterButton(.info, label: "Info")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    private func filterButton(_ level: ConsoleLevel?, label: String) -> some View {
        Button {
            filter = level
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(filter == level ? Color.blue.opacity(0.15) : Color.clear)
                .foregroundColor(filter == level ? .blue : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func executeInput() {
        guard !inputText.isEmpty else { return }
        let cmd = inputText

        let inputEntry = ConsoleEntry(level: .input, text: "> \(cmd)", timestamp: Date())
        messages.append(inputEntry)
        inputText = ""

        viewModel.webView?.evaluateJavaScript(cmd) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    let entry = ConsoleEntry(level: .error, text: "⚠ \(error.localizedDescription)", timestamp: Date())
                    self.messages.append(entry)
                } else {
                    let text: String
                    if let result = result {
                        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
                           let str = String(data: data, encoding: .utf8) {
                            text = str
                        } else {
                            text = "\(result)"
                        }
                    } else {
                        text = "undefined"
                    }
                    let entry = ConsoleEntry(level: .result, text: "← \(text)", timestamp: Date())
                    self.messages.append(entry)
                }
            }
        }
    }
}

// MARK: - Console Entry

enum ConsoleLevel: String {
    case log, warn, error, info, debug, input, result
}

struct ConsoleEntry: Identifiable {
    let id = UUID()
    let level: ConsoleLevel
    let text: String
    let timestamp: Date

    var color: Color {
        switch level {
        case .error: return .red
        case .warn: return .orange
        case .info: return .blue
        case .input: return .purple
        case .result: return .green
        default: return .primary
        }
    }

    var icon: String {
        switch level {
        case .error: return "exclamationmark.triangle.fill"
        case .warn: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        case .input: return "chevron.right"
        case .result: return "chevron.left"
        default: return "circle.fill"
        }
    }
}

struct ConsoleMessageRow: View {
    let entry: ConsoleEntry
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: entry.icon)
                        .font(.system(size: 10))
                        .foregroundColor(entry.color)
                        .frame(width: 14)
                        .padding(.top, 2)

                    Text(expanded ? entry.text : entry.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(entry.color)
                        .lineLimit(expanded ? nil : 3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(timeString(entry.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        Divider().opacity(0.3)
    }

    private var rowBackground: Color {
        switch entry.level {
        case .error: return Color.red.opacity(0.05)
        case .warn: return Color.orange.opacity(0.05)
        default: return Color.clear
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }
}
