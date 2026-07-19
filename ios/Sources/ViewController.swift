import UIKit
import WebKit

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
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
      webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  // MARK: window.print() -> render a real PDF and open the share sheet
  // (Save to Files, WhatsApp, Mail, AirDrop…). The app sets document.title
  // to "<client> - <agreement>" right before printing, so use it as the
  // file name. Letter size, zero margins: the letterhead bands are
  // full-bleed and .pg-body supplies the text margins.

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage) {
    guard message.name == "printPage" else { return }
    let raw = (webView.title?.isEmpty == false ? webView.title! : "TCO Agreement")
    let name = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined()
    let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    let renderer = UIPrintPageRenderer()
    renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
    renderer.setValue(page, forKey: "paperRect")
    renderer.setValue(page, forKey: "printableRect")
    let data = NSMutableData()
    UIGraphicsBeginPDFContextToData(data, page, nil)
    for i in 0..<renderer.numberOfPages {
      UIGraphicsBeginPDFPage()
      renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
    }
    UIGraphicsEndPDFContext()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".pdf")
    do { try data.write(to: url, options: .atomic) } catch { return }
    let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let pop = share.popoverPresentationController {   // iPad requires an anchor
      pop.sourceView = view
      pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
      pop.permittedArrowDirections = []
    }
    present(share, animated: true)
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
