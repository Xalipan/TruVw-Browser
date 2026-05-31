//
//  BrowserTabViewController.swift
//  Browser
//
//  Created by Amer Hukić on 10. 9. 2021..
//

import UIKit
import WebKit
import Foundation

protocol BrowserTabViewControllerDelegate: AnyObject {
  func tabViewController(_ tabViewController: BrowserTabViewController, didStartLoadingURL url: URL)
  func tabViewController(_ tabViewController: BrowserTabViewController, didChangeLoadingProgressTo progress: Float)
  func tabViewControllerDidScroll(yOffsetChange: CGFloat)
  func tabViewControllerDidEndDragging()
}

class BrowserTabViewController: UIViewController {
  private let contentView = BrowserTabContentView()
  private var isScrolling = false
  private var startYOffset = CGFloat(0)
  private var kvoObservations: [NSKeyValueObservation] = []
  var hasLoadedUrl = false
  weak var delegate: BrowserTabViewControllerDelegate?
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    let isBackgroundColorDark = contentView.statusBarBackgroundView.backgroundColor?.isDark ?? false
    return isBackgroundColorDark ? .lightContent : .darkContent
  }
  
  override func loadView() {
    view = contentView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupWebView()
  }
  
  func loadWebsite(from url: URL) {
    contentView.webView.load(URLRequest(url: url))
    hasLoadedUrl = true
    hideEmptyStateIfNeeded()
  }
  
  func showEmptyState() {
    UIView.animate(withDuration: 0.2) {
      self.contentView.emptyStateView.alpha = 1
    }
  }
  
  func hideEmptyStateIfNeeded() {
    guard hasLoadedUrl else { return }
    UIView.animate(withDuration: 0.2) {
      self.contentView.emptyStateView.alpha = 0
    }
  }
}

// MARK: Helper methods
private extension BrowserTabViewController {
  func setupWebView() {
    contentView.webView.scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
    contentView.webView.navigationDelegate = self

    kvoObservations = [
      contentView.webView.observe(\.url, options: .new) { [weak self] webView, _ in
        guard let self = self, let url = webView.url else { return }
        self.delegate?.tabViewController(self, didStartLoadingURL: url)
      },
      contentView.webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
        guard let self = self else { return }
        self.delegate?.tabViewController(self, didChangeLoadingProgressTo: Float(webView.estimatedProgress))
      },
      contentView.webView.observe(\.themeColor, options: .new) { [weak self] _, _ in
        self?.updateStatusBarColor()
      },
      contentView.webView.observe(\.underPageBackgroundColor, options: .new) { [weak self] _, _ in
        self?.updateStatusBarColor()
      }
    ]
  }
  
  func updateStatusBarColor() {
    let color = (contentView.webView.themeColor ?? contentView.webView.underPageBackgroundColor ?? .white).withAlphaComponent(1)
    contentView.statusBarBackgroundView.backgroundColor = color
    setNeedsStatusBarAppearanceUpdate()
  }
}

// MARK: Action methods
private extension BrowserTabViewController {
  @objc func handlePan(_ panGestureRecognizer: UIPanGestureRecognizer) {
    let yOffset = contentView.webView.scrollView.contentOffset.y
    switch panGestureRecognizer.state {
    case .began:
      startYOffset = yOffset
    case .changed:
      delegate?.tabViewControllerDidScroll(yOffsetChange: startYOffset - yOffset)
    case .failed, .ended, .cancelled:
      delegate?.tabViewControllerDidEndDragging()
    default:
      break
    }
  }
}

// MARK: WKNavigationDelegate
extension BrowserTabViewController: WKNavigationDelegate {
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if navigationAction.navigationType == .linkActivated {
      // handle redirects
      guard let url = navigationAction.request.url else { return }
      webView.load(URLRequest(url: url))
    }
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard let url = webView.url else { return }
    let rules = ConfigManager.shared.matchingRules(for: url)
    RuleEngine.shared.apply(rules: rules, to: webView, url: url)
  }
}
