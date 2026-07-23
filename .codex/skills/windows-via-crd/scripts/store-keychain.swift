import Foundation
import Security

let service = "dev.tener.codex.crd.Tener.pin"
let account = NSUserName()
let label = "Chrome Remote Desktop PIN for Tener"
let comment = "Used by the windows-via-crd Codex skill"

let inputData = FileHandle.standardInput.readDataToEndOfFile()
guard
    let input = String(data: inputData, encoding: .utf8)
else {
    fputs("Unable to read PIN input.\n", stderr)
    exit(1)
}

let pin = input.trimmingCharacters(in: .newlines)
guard pin.count >= 6, pin.allSatisfy({ $0.isASCII && $0.isNumber }) else {
    fputs("PIN must contain at least six ASCII digits.\n", stderr)
    exit(1)
}

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
]

let attributes: [String: Any] = [
    kSecValueData as String: Data(pin.utf8),
    kSecAttrLabel as String: label,
    kSecAttrComment as String: comment,
]

var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
if status == errSecItemNotFound {
    var newItem = query
    attributes.forEach { newItem[$0.key] = $0.value }
    status = SecItemAdd(newItem as CFDictionary, nil)
}

guard status == errSecSuccess else {
    fputs("Keychain update failed with status \(status).\n", stderr)
    exit(1)
}
