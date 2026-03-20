import Foundation

/// Errors thrown by ``CLIPSEngine`` operations.
///
/// Every throwing method on ``CLIPSEngine`` reports failures through this type,
/// so you can pattern-match on specific cases in your `catch` blocks:
///
/// ```swift
/// do {
///     try engine.assertFact("(sensor (type temperature) (value 98.6))")
/// } catch CLIPSError.assertionFailed(let detail) {
///     print("Bad fact: \(detail)")
/// }
/// ```
public enum CLIPSError: Error, LocalizedError, Sendable {

    /// The engine has not been started. Call ``CLIPSEngine/init()`` first.
    case engineNotReady

    /// A `(deftemplate …)`, `(defrule …)`, or other construct could not be compiled.
    case buildFailed(construct: String)

    /// `(assert …)` was rejected — usually a template mismatch or duplicate fact.
    case assertionFailed(fact: String)

    /// An expression passed to ``CLIPSEngine/evaluate(_:)`` could not be parsed or executed.
    case evaluationFailed(expression: String)

    /// No fact exists at the given index.
    case factNotFound(index: Int)

    /// No `defglobal` with this name exists in the current environment.
    case globalNotFound(name: String)

    /// No `defrule` with this name exists in the current environment.
    case ruleNotFound(name: String)

    /// A file-based operation (save / load) failed.
    case fileOperationFailed(path: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case .engineNotReady:
            return "CLIPS engine is not initialized."
        case .buildFailed(let construct):
            return "Failed to build construct: \(construct)"
        case .assertionFailed(let fact):
            return "Failed to assert fact: \(fact)"
        case .evaluationFailed(let expression):
            return "Failed to evaluate: \(expression)"
        case .factNotFound(let index):
            return "No fact at index \(index)."
        case .globalNotFound(let name):
            return "Global not found: \(name)"
        case .ruleNotFound(let name):
            return "Rule not found: \(name)"
        case .fileOperationFailed(let path, let detail):
            return "File operation failed at \(path): \(detail)"
        }
    }
}
