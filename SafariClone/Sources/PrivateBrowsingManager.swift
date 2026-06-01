import Foundation
import Combine

class PrivateBrowsingManager: ObservableObject {
    @Published var isPrivate: Bool = false

    func toggle() {
        isPrivate.toggle()
    }
}
