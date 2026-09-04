#!/usr/bin/env swift
import CryptoKit
import Foundation

// Kurzlebiges Token für die App-Store-Connect-API. Der private Schlüssel bleibt
// auf der Maschine und wird nie ausgegeben.
//
//   swift Scripts/asc-token.swift <keyPath> <keyID> <issuerID>

func base64url(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else { fatalError("usage: asc-token <keyPath> <keyID> <issuerID>") }
let key = try P256.Signing.PrivateKey(
    pemRepresentation: try String(contentsOfFile: arguments[1], encoding: .utf8))

let now = Int(Date().timeIntervalSince1970)
let header = #"{"alg":"ES256","kid":"\#(arguments[2])","typ":"JWT"}"#
let payload = #"{"iss":"\#(arguments[3])","iat":\#(now),"exp":\#(now + 900),"aud":"appstoreconnect-v1"}"#
let signingInput = "\(base64url(Data(header.utf8))).\(base64url(Data(payload.utf8)))"
let signature = try key.signature(for: Data(signingInput.utf8))
print("\(signingInput).\(base64url(signature.rawRepresentation))")
