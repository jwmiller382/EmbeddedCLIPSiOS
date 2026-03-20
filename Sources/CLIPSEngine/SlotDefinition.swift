import Foundation

/// Describes a slot in a CLIPS deftemplate.
///
/// Use the static factories to create slot definitions when calling
/// ``CLIPSEngine/defineTemplate(_:slots:)``:
///
/// ```swift
/// try engine.defineTemplate("sensor", slots: [
///     .slot("type"),
///     .slot("value", defaultValue: 0),
///     .multislot("readings"),
/// ])
/// ```
public struct SlotDefinition: Sendable {

    /// The slot name.
    public let name: String

    /// Whether this is a `multislot` (holds a list) or a `slot` (single value).
    public let isMultislot: Bool

    /// An optional default value for the slot.
    public let defaultValue: CLIPSValue?

    /// Creates a single-value slot definition.
    ///
    /// - Parameters:
    ///   - name: The slot name.
    ///   - defaultValue: Optional default value.
    /// - Returns: A `SlotDefinition` for use in ``CLIPSEngine/defineTemplate(_:slots:)``.
    public static func slot(_ name: String, defaultValue: CLIPSValue? = nil) -> SlotDefinition {
        SlotDefinition(name: name, isMultislot: false, defaultValue: defaultValue)
    }

    /// Creates a multi-value slot definition.
    ///
    /// - Parameters:
    ///   - name: The slot name.
    ///   - defaultValue: Optional default value.
    /// - Returns: A `SlotDefinition` for use in ``CLIPSEngine/defineTemplate(_:slots:)``.
    public static func multislot(_ name: String, defaultValue: CLIPSValue? = nil) -> SlotDefinition {
        SlotDefinition(name: name, isMultislot: true, defaultValue: defaultValue)
    }

    /// The CLIPS syntax for this slot, e.g. `(slot name)` or
    /// `(multislot readings (default 0))`.
    var clipsRepresentation: String {
        let kind = isMultislot ? "multislot" : "slot"
        var parts = "(\(kind) \(name)"
        if let def = defaultValue {
            parts += " (default \(def.clipsRepresentation))"
        }
        parts += ")"
        return parts
    }
}
