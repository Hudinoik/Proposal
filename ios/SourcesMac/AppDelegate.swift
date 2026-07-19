import Cocoa
import WebKit
import Speech
import AVFoundation
import PDFKit
import UniformTypeIdentifiers

/* Native macOS shell around index.html for Mac App Store / TestFlight
   distribution (the website-download Mac app remains the Electron build).
   Mirrors the iOS shell: window.print() -> the macOS print panel (which
   includes Save as PDF), JS dialogs -> NSAlert, external links -> browser. */
@main
class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
  var window: NSWindow!
  var webView: WKWebView!

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildMenu()

    let controller = WKUserContentController()
    let printOverride = "window.print = function(){ window.webkit.messageHandlers.printPage.postMessage(''); };"
    controller.addUserScript(WKUserScript(source: printOverride, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    controller.add(self, name: "printPage")
    controller.add(self, name: "voiceStart")
    controller.add(self, name: "voiceStop")

    let config = WKWebViewConfiguration()
    config.userContentController = controller
    if #available(macOS 13.3, *) { config.preferences.shouldPrintBackgrounds = true }

    webView = WKWebView(frame: .zero, configuration: config)
    webView.uiDelegate = self
    webView.navigationDelegate = self

    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1500, height: 980),
                      styleMask: [.titled, .closable, .miniaturizable, .resizable],
                      backing: .buffered, defer: false)
    window.minSize = NSSize(width: 900, height: 620)
    window.title = "TCO Agreement Generator"
    window.contentView = webView
    window.center()
    window.makeKeyAndOrderFront(nil)

    if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
      webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

  /* A minimal main menu so Quit and text editing shortcuts work —
     a menu-less Mac app cannot copy/paste into its text fields. */
  private func buildMenu() {
    let main = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About TCO Agreement Generator",
                    action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    appMenu.addItem(withTitle: "Quit TCO Agreement Generator",
                    action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    main.addItem(appItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = editMenu
    main.addItem(editItem)

    NSApp.mainMenu = main
  }

  // MARK: window.print() -> capture the laid-out pages into a PDF (identical
  // to the preview: full-bleed bands, no print-engine margins) and save it.

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage) {
    if message.name == "voiceStart" { startVoice(); return }
    if message.name == "voiceStop" { stopVoice(); return }
    guard message.name == "printPage" else { return }
    exportPagesPDF()
  }

  private func exportPagesPDF() {
    let prep = "(function(){var n=document.querySelectorAll('.doc.page').length;" +
               "if(n>0){document.body.classList.add('pdfmode');window.scrollTo(0,0);}return n;})()"
    webView.evaluateJavaScript(prep) { res, _ in
      let n = (res as? NSNumber)?.intValue ?? 0
      guard n > 0 else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        // note: the intermediate capture is one tall page (n x 1056pt);
        // PDF caps a page at 14400pt, so this supports up to 13 sheets —
        // beyond any agreement produced today
        self.webView.createPDF(configuration: WKPDFConfiguration()) { result in
          self.webView.evaluateJavaScript(
            "document.body.classList.remove('pdfmode'); if (window.fitPreviewPages) fitPreviewPages();",
            completionHandler: nil)
          if case .success(let data) = result { self.sliceAndSave(data: data, pageCount: n) }
        }
      }
    }
  }

  private func sliceAndSave(data: Data, pageCount: Int) {
    guard let src = PDFDocument(data: data), let big = src.page(at: 0), pageCount > 0 else { return }
    let media = big.bounds(for: .mediaBox)
    let pageH = media.height / CGFloat(pageCount)
    let out = PDFDocument()
    for i in 0..<pageCount {
      guard let slice = big.copy() as? PDFPage else { continue }
      let box = CGRect(x: media.minX,
                       y: media.minY + media.height - CGFloat(i + 1) * pageH,
                       width: media.width, height: pageH)
      slice.setBounds(box, for: .mediaBox)
      slice.setBounds(box, for: .cropBox)
      out.insert(slice, at: out.pageCount)
    }
    guard out.pageCount > 0, let pdf = out.dataRepresentation() else { return }
    let raw = (webView.title?.isEmpty == false ? webView.title! : "TCO Agreement")
    let name = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined()
    let panel = NSSavePanel()
    panel.nameFieldStringValue = name + ".pdf"
    panel.allowedContentTypes = [.pdf]
    panel.beginSheetModal(for: window) { resp in
      guard resp == .OK, let url = panel.url else { return }
      try? pdf.write(to: url, options: .atomic)
    }
  }

  // MARK: voice notes — live on-device speech recognition streamed to the page

  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  private var audioEngine: AVAudioEngine?
  private var recRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recTask: SFSpeechRecognitionTask?
  private var voiceActive = false
  private var lastTranscript = ""

  private func jsCall(_ fn: String, _ text: String) {
    guard let data = try? JSONSerialization.data(withJSONObject: [text]),
          let arr = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.\(fn)(\(arr)[0])", completionHandler: nil)
  }

  private func startVoice() {
    SFSpeechRecognizer.requestAuthorization { auth in
      DispatchQueue.main.async {
        guard auth == .authorized else {
          self.jsCall("tcoVoiceError", "Speech recognition permission was declined. Enable it in System Settings > Privacy & Security."); return
        }
        AVCaptureDevice.requestAccess(for: .audio) { ok in
          DispatchQueue.main.async {
            guard ok else {
              self.jsCall("tcoVoiceError", "Microphone permission was declined. Enable it in System Settings > Privacy & Security."); return
            }
            self.beginRecording()
          }
        }
      }
    }
  }

  private func beginRecording() {
    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
      jsCall("tcoVoiceError", "Speech recognition isn't available on this Mac right now."); return
    }
    let engine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    let input = engine.inputNode
    input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
      request.append(buffer)
    }
    engine.prepare()
    do { try engine.start() } catch { jsCall("tcoVoiceError", "Could not start the microphone."); return }

    audioEngine = engine
    recRequest = request
    voiceActive = true
    lastTranscript = ""
    recTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }
      DispatchQueue.main.async {
        if let r = result {
          self.lastTranscript = r.bestTranscription.formattedString
          if r.isFinal { self.finishVoice(); return }
          if self.voiceActive { self.jsCall("tcoVoicePartial", self.lastTranscript) }
        }
        if error != nil { self.finishVoice() }
      }
    }
  }

  private func stopVoice() {
    recRequest?.endAudio()
    audioEngine?.stop()
  }

  private func finishVoice() {
    guard voiceActive else { return }
    voiceActive = false
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil; recRequest = nil; recTask = nil
    jsCall("tcoVoiceFinal", lastTranscript)
  }

  // MARK: external links -> default browser

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction,
               windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
    return nil
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url, let scheme = url.scheme,
       scheme == "http" || scheme == "https" {
      NSWorkspace.shared.open(url)
      decisionHandler(.cancel)
      return
    }
    decisionHandler(.allow)
  }

  // MARK: alert()/confirm()/prompt() -> native dialogs

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    let a = NSAlert(); a.messageText = ""; a.informativeText = message
    a.beginSheetModal(for: window) { _ in completionHandler() }
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    let a = NSAlert(); a.messageText = ""; a.informativeText = message
    a.addButton(withTitle: "OK"); a.addButton(withTitle: "Cancel")
    a.beginSheetModal(for: window) { r in completionHandler(r == .alertFirstButtonReturn) }
  }

  func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
               defaultText: String?, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping (String?) -> Void) {
    let a = NSAlert(); a.messageText = ""; a.informativeText = prompt
    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    field.stringValue = defaultText ?? ""
    a.accessoryView = field
    a.addButton(withTitle: "OK"); a.addButton(withTitle: "Cancel")
    a.beginSheetModal(for: window) { r in
      completionHandler(r == .alertFirstButtonReturn ? field.stringValue : nil)
    }
  }
}
