//  WASICompat.swift — WebAssembly only: the string helpers CLIPSEngine used from Foundation, which FoundationEssentials lacks.
#if os(WASI)
import FoundationEssentials

/// The character classes trimmed and split by (FoundationEssentials has no CharacterSet).
struct CharacterSet: Sendable {
    let test: @Sendable (Character) -> Bool
    init(charactersIn s: String) { let set = Set(s); test = { set.contains($0) } }
    init(_ f: @escaping @Sendable (Character) -> Bool) { test = f }
    static let whitespaces = CharacterSet { $0.isWhitespace && !$0.isNewline }
    static let whitespacesAndNewlines = CharacterSet { $0.isWhitespace }
    static let newlines = CharacterSet { $0.isNewline }
}

extension String {
    func trimmingCharacters(in set: CharacterSet) -> String {
        guard let a = firstIndex(where: { !set.test($0) }) else { return "" }
        let b = lastIndex(where: { !set.test($0) })!
        return String(self[a...b])
    }
    func components(separatedBy set: CharacterSet) -> [String] {
        var out: [String] = [], cur = ""
        for c in self { if set.test(c) { out.append(cur); cur = "" } else { cur.append(c) } }
        out.append(cur)
        return out
    }
}
#endif
