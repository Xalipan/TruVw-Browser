//
//  URLGenerator.swift
//  Browser
//
//  Created by Amer Hukić on 21. 9. 2021..
//

import Foundation

class URLGenerator {
  private let urlValidator: URLValidator
  
  init(urlValidator: URLValidator = .init()) {
    self.urlValidator = urlValidator
  }
  
  func getURL(for text: String) -> URL? {
    guard urlValidator.isValidURL(text.lowercased()) else {
      return getGoogleSearchURL(for: text)
    }
    
    let lowercased = text.lowercased()
    guard lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") else {
      return URL(string: "http://\(text)")
    }
    
    return URL(string: text)
  }
}

private extension URLGenerator {
  func getGoogleSearchURL(for text: String) -> URL? {
    guard let encodedSearchString = text.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
      return nil
    }
    let queryString = "https://www.google.com/search?q=\(encodedSearchString)"
    return URL(string: queryString)
  }
}
