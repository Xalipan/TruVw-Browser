import SwiftUI
import WebKit

struct DOMInspectorView: View {
    @ObservedObject var viewModel: WebViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selector = ""
    @State private var queryResult: [String: Any] = [:]
    @State private var queryAllResults: [[String: Any]] = []
    @State private var documentState: [String: Any] = [:]
    @State private var selectedTab = 0
    @State private var manipulateSelector = ""
    @State private var manipulateProperty = ""
    @State private var manipulateValue = ""
    @State private var selectedManipulation = 0
    @State private var injectCSSText = ""
    @State private var injectJSText = ""
    @State private var jsResult = ""
    @State private var pageSource = ""
    @State private var showPageSource = false
    @State private var isLoading = false

    private let manipulations = ["setAttribute", "removeAttribute", "setStyle", "addClass", "removeClass", "setInnerHTML", "setTextContent", "removeElement", "click", "focus", "scrollIntoView"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Query").tag(0)
                    Text("Manipulate").tag(1)
                    Text("Inject").tag(2)
                    Text("Info").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(12)

                TabView(selection: $selectedTab) {
                    queryTab.tag(0)
                    manipulateTab.tag(1)
                    injectTab.tag(2)
                    infoTab.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("DOM Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { loadDocumentState() }
    }

    // MARK: - Query Tab

    private var queryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CSS Selector").font(.headline)
                    HStack {
                        TextField("e.g. h1, .className, #id", text: $selector)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("Query") { runQuery() }
                            .buttonStyle(.borderedProminent)
                            .disabled(selector.isEmpty)
                        Button("All") { runQueryAll() }
                            .buttonStyle(.bordered)
                            .disabled(selector.isEmpty)
                    }
                }

                if !queryResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Match").font(.headline)
                        DOMResultView(data: queryResult)
                    }
                }

                if !queryAllResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(queryAllResults.count) Matches").font(.headline)
                        ForEach(Array(queryAllResults.prefix(20).enumerated()), id: \.offset) { i, result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("[\(i)] \(result["tagName"] as? String ?? "")").font(.caption.weight(.bold))
                                DOMResultView(data: result)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Manipulate Tab

    private var manipulateTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Selector").font(.headline)
                    TextField("CSS Selector", text: $manipulateSelector)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Operation").font(.headline)
                    Picker("Operation", selection: $selectedManipulation) {
                        ForEach(Array(manipulations.enumerated()), id: \.offset) { i, op in
                            Text(op).tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                if needsPropertyField {
                    TextField("Property/Attribute Name", text: $manipulateProperty)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }

                if needsValueField {
                    TextField("Value", text: $manipulateValue)
                        .textFieldStyle(.roundedBorder)
                }

                Button("Execute") { executeManipulation() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(manipulateSelector.isEmpty)

                quickActionsSection
            }
            .padding(16)
        }
    }

    private var needsPropertyField: Bool {
        let op = manipulations[selectedManipulation]
        return ["setAttribute", "removeAttribute", "setStyle", "addClass", "removeClass"].contains(op)
    }

    private var needsValueField: Bool {
        let op = manipulations[selectedManipulation]
        return ["setAttribute", "setStyle", "setInnerHTML", "setTextContent"].contains(op)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                QuickActionButton(title: "Hide Ads", icon: "eye.slash") {
                    executeScript("document.querySelectorAll('[class*=\"ad\"], [id*=\"ad\"], [class*=\"banner\"], iframe[src*=\"ad\"]').forEach(e => e.style.display='none');")
                }
                QuickActionButton(title: "Show All", icon: "eye") {
                    executeScript("document.querySelectorAll('*').forEach(e => e.style.display='');")
                }
                QuickActionButton(title: "Scroll Top", icon: "arrow.up.to.line") {
                    executeScript("window.scrollTo({top:0, behavior:'smooth'});")
                }
                QuickActionButton(title: "Night Mode", icon: "moon.fill") {
                    executeScript("""
                    document.body.style.filter = document.body.style.filter === 'invert(1) hue-rotate(180deg)' ? '' : 'invert(1) hue-rotate(180deg)';
                    """)
                }
                QuickActionButton(title: "Page Source", icon: "doc.text") {
                    loadPageSource()
                }
                QuickActionButton(title: "Highlight All", icon: "sparkles") {
                    if !manipulateSelector.isEmpty {
                        executeScript("document.querySelectorAll('\(manipulateSelector)').forEach(e => { e.style.outline='3px solid #ff0000'; });")
                    }
                }
            }
        }
    }

    // MARK: - Inject Tab

    private var injectTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inject CSS").font(.headline)
                    TextEditor(text: $injectCSSText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    Button("Inject CSS") {
                        guard let webView = viewModel.webView else { return }
                        injectCSS(injectCSSText, into: webView)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(injectCSSText.isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Inject JavaScript").font(.headline)
                    TextEditor(text: $injectJSText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    Button("Execute JS") {
                        guard let webView = viewModel.webView else { return }
                        webView.evaluateJavaScript(injectJSText) { result, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    jsResult = "Error: \(error.localizedDescription)"
                                } else if let result = result {
                                    jsResult = "\(result)"
                                } else {
                                    jsResult = "undefined"
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(injectJSText.isEmpty)

                    if !jsResult.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Result").font(.caption.weight(.bold))
                            Text(jsResult)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preset Scripts").font(.headline)
                    ForEach(presetScripts, id: \.0) { script in
                        Button(script.0) {
                            injectJSText = script.1
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(16)
        }
    }

    private var presetScripts: [(String, String)] {
        [
            ("Get All Links", "JSON.stringify(Array.from(document.links).map(l => l.href).slice(0, 50))"),
            ("Get All Images", "JSON.stringify(Array.from(document.images).map(i => i.src).slice(0, 20))"),
            ("Get Meta Tags", "JSON.stringify(Array.from(document.querySelectorAll('meta')).map(m => ({ name: m.name, content: m.content })))"),
            ("Get Cookies", "document.cookie"),
            ("Get localStorage", "JSON.stringify(Object.fromEntries(Object.keys(localStorage).map(k => [k, localStorage.getItem(k)])))"),
            ("Count Elements", "JSON.stringify({ divs: document.querySelectorAll('div').length, spans: document.querySelectorAll('span').length, links: document.links.length, images: document.images.length })"),
            ("Remove All Ads", "document.querySelectorAll('[class*=\"ad\"], [id*=\"ad\"], [class*=\"banner\"], .advertisement, .advert').forEach(e => e.remove())"),
            ("Enable Dark Mode", "document.body.style.background='#1a1a1a'; document.body.style.color='#e0e0e0';"),
        ]
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if documentState.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    Text("Page Information").font(.headline)
                    ForEach(Array(documentState.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)
                            Text("\(value)")
                                .font(.caption)
                                .lineLimit(3)
                        }
                        Divider()
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Actions

    private func runQuery() {
        guard let webView = viewModel.webView else { return }
        let script = """
        (function() {
            var el = document.querySelector('\(selector.replacingOccurrences(of: "'", with: "\\'"))');
            if (!el) return null;
            return {
                tagName: el.tagName,
                id: el.id,
                className: el.className,
                textContent: el.textContent.substring(0, 300),
                innerHTML: el.innerHTML.substring(0, 500),
                attributes: Array.from(el.attributes).reduce((acc, a) => { acc[a.name] = a.value; return acc; }, {}),
                childCount: el.children.length
            };
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            DispatchQueue.main.async {
                self.queryResult = result as? [String: Any] ?? [:]
                self.queryAllResults = []
            }
        }
    }

    private func runQueryAll() {
        guard let webView = viewModel.webView else { return }
        let script = """
        (function() {
            return Array.from(document.querySelectorAll('\(selector.replacingOccurrences(of: "'", with: "\\'"))'))
                .slice(0, 30)
                .map(el => ({ tagName: el.tagName, id: el.id, className: el.className, textContent: el.textContent.substring(0, 100) }));
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            DispatchQueue.main.async {
                self.queryAllResults = result as? [[String: Any]] ?? []
                self.queryResult = [:]
            }
        }
    }

    private func executeManipulation() {
        guard let webView = viewModel.webView else { return }
        let sel = manipulateSelector.replacingOccurrences(of: "'", with: "\\'")
        let prop = manipulateProperty.replacingOccurrences(of: "'", with: "\\'")
        let val = manipulateValue.replacingOccurrences(of: "'", with: "\\'")
        let op = manipulations[selectedManipulation]
        var script = ""
        switch op {
        case "setAttribute": script = "document.querySelectorAll('\(sel)').forEach(e => e.setAttribute('\(prop)', '\(val)'));"
        case "removeAttribute": script = "document.querySelectorAll('\(sel)').forEach(e => e.removeAttribute('\(prop)'));"
        case "setStyle": script = "document.querySelectorAll('\(sel)').forEach(e => e.style['\(prop)'] = '\(val)');"
        case "addClass": script = "document.querySelectorAll('\(sel)').forEach(e => e.classList.add('\(prop)'));"
        case "removeClass": script = "document.querySelectorAll('\(sel)').forEach(e => e.classList.remove('\(prop)'));"
        case "setInnerHTML": script = "var el = document.querySelector('\(sel)'); if(el) el.innerHTML = '\(val)';"
        case "setTextContent": script = "document.querySelectorAll('\(sel)').forEach(e => e.textContent = '\(val)');"
        case "removeElement": script = "document.querySelectorAll('\(sel)').forEach(e => e.remove());"
        case "click": script = "var el = document.querySelector('\(sel)'); if(el) el.click();"
        case "focus": script = "var el = document.querySelector('\(sel)'); if(el) el.focus();"
        case "scrollIntoView": script = "var el = document.querySelector('\(sel)'); if(el) el.scrollIntoView({behavior:'smooth',block:'center'});"
        default: break
        }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func executeScript(_ script: String) {
        viewModel.webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func injectCSS(_ css: String, into webView: WKWebView) {
        let escaped = css.replacingOccurrences(of: "`", with: "\\`")
        webView.evaluateJavaScript("""
        (function() {
            var s = document.createElement('style');
            s.textContent = `\(escaped)`;
            document.head.appendChild(s);
        })();
        """, completionHandler: nil)
    }

    private func loadDocumentState() {
        guard let webView = viewModel.webView else { return }
        webView.evaluateJavaScript("""
        ({ url: location.href, title: document.title, readyState: document.readyState,
           bodyWordCount: document.body ? document.body.innerText.split(/\\s+/).length : 0,
           linkCount: document.links.length, imageCount: document.images.length,
           scriptCount: document.scripts.length, formCount: document.forms.length,
           characterSet: document.characterSet, lastModified: document.lastModified })
        """) { result, _ in
            DispatchQueue.main.async {
                self.documentState = result as? [String: Any] ?? [:]
            }
        }
    }

    private func loadPageSource() {
        viewModel.webView?.evaluateJavaScript("document.documentElement.outerHTML") { result, _ in
            DispatchQueue.main.async {
                self.pageSource = result as? String ?? ""
                self.showPageSource = true
            }
        }
    }
}

// MARK: - Supporting Views

struct DOMResultView: View {
    let data: [String: Any]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(data.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                HStack(alignment: .top) {
                    Text(key)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                        .frame(width: 110, alignment: .leading)
                    Text("\(value)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(4)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
