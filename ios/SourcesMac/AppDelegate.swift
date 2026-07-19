import Cocoa
import WebKit

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

  // MARK: window.print() -> macOS print panel (includes "Save as PDF")

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage) {
    guard message.name == "printPage" else { return }
    let info = NSPrintInfo()
    info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
    info.horizontalPagination = .fit
    info.verticalPagination = .automatic
    let op = webView.printOperation(with: info)
    op.showsPrintPanel = true
    op.showsProgressPanel = true
    // WKWebView's print operation renders empty unless the view gets a frame
    op.view?.frame = webView.bounds
    op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
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
