//
//  LLDBHelpers.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 25/8/2026.
//

import Foundation
#if DEBUG
/// Global helper for LLDB console debugging.
/// Usage in Xcode console: `po printJSON(data)` or `po printJSON(jsonString)`
func printJSON(_ data: Data) {
    if let object = try? JSONSerialization.jsonObject(with: data),
       let prettyData = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
       let prettyString = String(data: prettyData, encoding: .utf8) {
        print(prettyString)
    } else {
        print("❌ Invalid JSON Data")
    }
}

/// Overload for string input directly
func printJSON(_ jsonString: String) {
    guard let data = jsonString.data(using: .utf8) else {
        print("❌ Unable to convert String to UTF-8 Data")
        return
    }
    printJSON(data)
}
#endif
