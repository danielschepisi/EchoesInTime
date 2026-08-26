//
//  AuthRequestBody.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import Foundation

struct AuthRequestBody: Encodable {
    let email: String
    let password: String
    let returnSecureToken: Bool = true
}
