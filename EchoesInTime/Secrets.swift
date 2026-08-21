//
//  Secrets.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import Foundation

enum Secrets {
    static var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let key = plist["API_KEY"] as? String else {
            fatalError("Missing Secrets.plist or API_KEY in project configuration.")
        }
        return key
    }
    
    static var storageBucket: String {
            guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
                  let dict = NSDictionary(contentsOfFile: filePath),
                  let value = dict["STORAGE_BUCKET"] as? String else {
                fatalError("STORAGE_BUCKET not found in Secrets.plist")
            }
            return value
        }
}
