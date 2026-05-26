import SwiftUI
import UIKit

extension UIApplication {
    static var keyWindow: UIWindow? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

extension Color {
    static let safariBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
}

extension URL {
    var isHTTPS: Bool { scheme == "https" }
    var displayHost: String { host ?? absoluteString }
}

extension String {
    var isValidURL: Bool {
        guard let url = URL(string: self), url.scheme != nil, url.host != nil else { return false }
        return true
    }
}
