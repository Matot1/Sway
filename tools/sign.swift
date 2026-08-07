import Foundation
import CryptoKit

let args = CommandLine.arguments

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("ERROR: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

guard args.count >= 2 else {
    print("""
    Usage:
      swift sign.swift genkeys <privateKeyFile>     Generate Ed25519 keypair, save private seed (base64), print public key
      swift sign.swift sign <privateKeyFile> <file> Sign file, print base64 Ed25519 signature
    """)
    exit(0)
}

switch args[1] {
case "genkeys":
    guard args.count >= 3 else { fail("missing private key output path") }
    let key = Curve25519.Signing.PrivateKey()
    let privB64 = key.rawRepresentation.base64EncodedString()
    do {
        try privB64.write(toFile: args[2], atomically: true, encoding: .utf8)
    } catch {
        fail("failed to write private key: \(error)")
    }
    print(key.publicKey.rawRepresentation.base64EncodedString())

case "sign":
    guard args.count >= 4 else { fail("usage: sign <privateKeyFile> <file>") }
    guard let privB64 = try? String(contentsOfFile: args[2], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
          let seed = Data(base64Encoded: privB64) else {
        fail("cannot read private key from \(args[2])")
    }
    guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed) else {
        fail("invalid private key")
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: args[3])) else {
        fail("cannot read file \(args[3])")
    }
    guard let sig = try? key.signature(for: data) else {
        fail("signing failed")
    }
    print(sig.base64EncodedString())

default:
    fail("unknown command \(args[1])")
}
