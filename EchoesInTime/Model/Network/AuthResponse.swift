//
//  AuthResponse.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import Foundation

struct AuthResponse: Decodable {
    let idToken: String
    let localId: String
    let email: String
}
