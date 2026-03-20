import Foundation

/// A type-safe representation of a value in the CLIPS engine.
///
/// CLIPS is dynamically typed — slots can hold strings, symbols, integers,
/// floats, or booleans. `CLIPSValue` bridges that world into Swift so you can
/// inject facts with native types and read results back without string parsing.
///
/// ## Creating values
///
/// Use the enum cases directly, or rely on the Swift literal protocols:
///
/// ```swift
/// let name: CLIPSValue = "Alice"        // .string("Alice")
/// let age:  CLIPSValue = 30             // .integer(30)
/// let temp: CLIPSValue = 98.6           // .float(98.6)
/// let ok:   CLIPSValue = true           // .boolean(true)
/// let sym = CLIPSValue.symbol("active") // CLIPS symbol (unquoted)
/// ```
///
/// ## Reading values back
///
/// After calling ``CLIPSEngine/evaluate(_:)`` or ``CLIPSEngine/getGlobal(_:)``,
/// pattern-match or use the typed accessors:
///
/// ```swift
/// let result = try engine.evaluate("(+ 2 3)")
/// if let n = result.intValue {
///     print("Sum is \(n)")   // 5
/// }
/// ```
public enum CLIPSValue: Sendable, Equatable, CustomStringConvertible {

    /// A quoted string value — `"hello"` in CLIPS.
    case string(String)

    /// An unquoted symbol — `active`, `TRUE`, `nil` in CLIPS.
    case symbol(String)

    /// A 64-bit integer.
    case integer(Int)

    /// A 64-bit floating-point number.
    case float(Double)

    /// A boolean (`TRUE` / `FALSE` symbol in CLIPS).
    case boolean(Bool)

    // MARK: - Typed accessors

    /// The `String` payload if this is `.string`, otherwise `nil`.
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    /// The `String` payload if this is `.symbol`, otherwise `nil`.
    public var symbolValue: String? {
        if case .symbol(let v) = self { return v }
        return nil
    }

    /// The `Int` payload if this is `.integer`, otherwise `nil`.
    public var intValue: Int? {
        if case .integer(let v) = self { return v }
        return nil
    }

    /// The `Double` payload if this is `.float`, otherwise `nil`.
    public var floatValue: Double? {
        if case .float(let v) = self { return v }
        return nil
    }

    /// The `Bool` payload if this is `.boolean`, otherwise `nil`.
    public var boolValue: Bool? {
        if case .boolean(let v) = self { return v }
        return nil
    }

    // MARK: - CLIPS syntax

    /// The value formatted for embedding inside a CLIPS expression.
    ///
    /// - `.string("hello")` → `"hello"` (with quotes)
    /// - `.symbol("active")` → `active`
    /// - `.integer(42)` → `42`
    /// - `.float(3.14)` → `3.14`
    /// - `.boolean(true)` → `TRUE`
    public var clipsRepresentation: String {
        switch self {
        case .string(let s):  return "\"\(s)\""
        case .symbol(let s):  return s
        case .integer(let n): return "\(n)"
        case .float(let d):   return "\(d)"
        case .boolean(let b): return b ? "TRUE" : "FALSE"
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .string(let s):  return "string(\"\(s)\")"
        case .symbol(let s):  return "symbol(\(s))"
        case .integer(let n): return "integer(\(n))"
        case .float(let d):   return "float(\(d))"
        case .boolean(let b): return "boolean(\(b))"
        }
    }

    // MARK: - Parsing from C layer strings

    /// Parses a raw string returned by the C bridge into a typed `CLIPSValue`.
    ///
    /// The C layer returns all results as strings. This method inspects the
    /// content and promotes it to the most specific type:
    ///
    /// - `"TRUE"` / `"FALSE"` → `.boolean`
    /// - Parseable as `Int` → `.integer`
    /// - Parseable as `Double` → `.float`
    /// - Everything else → `.string`
    static func parse(_ raw: String) -> CLIPSValue {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == "TRUE"  { return .boolean(true) }
        if trimmed == "FALSE" { return .boolean(false) }

        if let intVal = Int(trimmed) {
            return .integer(intVal)
        }

        if let doubleVal = Double(trimmed) {
            return .float(doubleVal)
        }

        return .string(trimmed)
    }
}

// MARK: - Literal conformances

extension CLIPSValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension CLIPSValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension CLIPSValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .float(value)
    }
}

extension CLIPSValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}
