import UIKit
import WebKit
import Speech
import AVFoundation

/* Native shell around index.html (copied into Resources/ at build time —
   the HTML file is the app, same as the browser and desktop versions).
   Provides what a plain WKWebView is missing:
   - window.print() -> the iOS print sheet (which offers Save as PDF / share)
   - alert()/confirm()/prompt() -> native dialogs (WKWebView drops them otherwise)
   - external links (claude.ai etc.) -> Safari, so the app stays on the form */
class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
  var webView: WKWebView!

  override func viewDidLoad() {
    super.viewDidLoad()
    // navy #052B6A behind the status bar, matching the app chrome
    view.backgroundColor = UIColor(red: 5/255.0, green: 43/255.0, blue: 106/255.0, alpha: 1)

    let controller = WKUserContentController()
    let printOverride = "window.print = function(){ window.webkit.messageHandlers.printPage.postMessage(''); };"
    controller.addUserScript(WKUserScript(source: printOverride, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    controller.add(self, name: "printPage")
    controller.add(self, name: "voiceStart")
    controller.add(self, name: "voiceStop")

    let config = WKWebViewConfiguration()
    config.userContentController = controller

    webView = WKWebView(frame: .zero, configuration: config)
    webView.uiDelegate = self
    webView.navigationDelegate = self
    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.scrollView.bounces = false
    webView.scrollView.alwaysBounceVertical = false
    webView.scrollView.alwaysBounceHorizontal = false
    webView.scrollView.showsHorizontalScrollIndicator = false
    view.addSubview(webView)
    let trail = webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    let bottom = webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      trail, bottom,
    ])
    trailingC = trail
    bottomC = bottom
    widthC = webView.widthAnchor.constraint(equalToConstant: 816)
    heightC = webView.heightAnchor.constraint(equalToConstant: 1056)

    if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
      webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  // MARK: window.print() -> photograph each laid-out page and compose the
  // PDF ourselves. The web view is temporarily resized to exactly one sheet
  // (816x1056), each page is scrolled into view and snapshotted at 2x, and
  // the snapshots are drawn full-bleed onto US-letter PDF pages — so the PDF
  // matches the preview by construction: no engine margins, no font
  // re-scaling, true edge-to-edge bands.

  private var trailingC: NSLayoutConstraint?
  private var bottomC: NSLayoutConstraint?
  private var widthC: NSLayoutConstraint?
  private var heightC: NSLayoutConstraint?

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage) {
    if message.name == "voiceStart" { startVoice(); return }
    if message.name == "voiceStop" { stopVoice(); return }
    guard message.name == "printPage" else { return }
    exportPagesPDF()
  }

  private func exportPagesPDF() {
    let prep = "(function(){var n=document.querySelectorAll('.doc.page').length;" +
               "if(n>0){document.body.classList.add('pdfmode');" +
               "var pg=document.querySelector('.pages'); if(pg) pg.style.zoom='';" +
               "window.scrollTo(0,0);}return n;})()"
    webView.evaluateJavaScript(prep) { res, _ in
      let n = (res as? NSNumber)?.intValue ?? 0
      guard n > 0 else { return }
      // size the web view to exactly one sheet
      self.trailingC?.isActive = false
      self.bottomC?.isActive = false
      self.widthC?.isActive = true
      self.heightC?.isActive = true
      self.view.layoutIfNeeded()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.snapshotPage(0, of: n, collected: [])
      }
    }
  }

  private func snapshotPage(_ i: Int, of n: Int, collected: [Data]) {
    if i >= n { finishExport(collected); return }
    webView.evaluateJavaScript("window.scrollTo(0, \(i * 1056));") { _, _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        let cfg = WKSnapshotConfiguration()
        cfg.rect = CGRect(x: 0, y: 0, width: 816, height: 1056)
        cfg.afterScreenUpdates = true
        cfg.snapshotWidth = 1632   // 2x for crisp text in the PDF
        self.webView.takeSnapshot(with: cfg) { image, _ in
          var arr = collected
          if let jpg = image?.jpegData(compressionQuality: 0.88) { arr.append(jpg) }
          self.snapshotPage(i + 1, of: n, collected: arr)
        }
      }
    }
  }

  private func restoreLayout() {
    widthC?.isActive = false
    heightC?.isActive = false
    trailingC?.isActive = true
    bottomC?.isActive = true
    view.layoutIfNeeded()
    webView.evaluateJavaScript(
      "document.body.classList.remove('pdfmode'); window.scrollTo(0,0); if (window.fitPreviewPages) fitPreviewPages();",
      completionHandler: nil)
  }

  private func finishExport(_ pages: [Data]) {
    restoreLayout()
    guard !pages.isEmpty else { return }
    let sheet = CGRect(x: 0, y: 0, width: 612, height: 792)   // US letter in points
    let renderer = UIGraphicsPDFRenderer(bounds: sheet)
    let pdf = renderer.pdfData { ctx in
      for d in pages {
        ctx.beginPage()
        UIImage(data: d)?.draw(in: sheet)
      }
    }
    let raw = (webView.title?.isEmpty == false ? webView.title! : "TCO Agreement")
    let name = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".pdf")
    do { try pdf.write(to: url, options: .atomic) } catch { return }
    let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let pop = share.popoverPresentationController {   // iPad requires an anchor
      pop.sourceView = view
      pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
      pop.permittedArrowDirections = []
    }
    present(share, animated: true)
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
          self.jsCall("tcoVoiceError", "Speech recognition permission was declined. Enable it under Settings > TCO Agreements."); return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
          DispatchQueue.main.async {
            guard ok else {
              self.jsCall("tcoVoiceError", "Microphone permission was declined. Enable it under Settings > TCO Agreements."); return
            }
            self.beginRecording()
          }
        }
      }
    }
  }

  private func beginRecording() {
    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
      jsCall("tcoVoiceError", "Speech recognition isn't available on this device right now."); return
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch { jsCall("tcoVoiceError", "Could not access the microphone."); return }

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
    // the recognizer delivers its final result (or an error) after endAudio;
    // finishVoice fires exactly once from that callback
  }

  private func finishVoice() {
    guard voiceActive else { return }
    voiceActive = false
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    audioEngine = nil; recRequest = nil; recTask = nil
    jsCall("tcoVoiceFinal", lastTranscript)
  }

  // MARK: external links -> Safari

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction,
               windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let url = navigationAction.request.url { UIApplication.shared.open(url) }
    return nil
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url, let scheme = url.scheme,
       scheme == "http" || scheme == "https" {
      UIApplication.shared.open(url)
      decisionHandler(.cancel)
      return
    }
    decisionHandler(.allow)
  }

  // MARK: alert()/confirm()/prompt() -> native dialogs

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
    present(alert, animated: true)
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
    present(alert, animated: true)
  }

  func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
               defaultText: String?, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping (String?) -> Void) {
    let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
    alert.addTextField { $0.text = defaultText }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
      completionHandler(alert?.textFields?.first?.text)
    })
    present(alert, animated: true)
  }
}
