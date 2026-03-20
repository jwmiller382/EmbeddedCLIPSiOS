import Foundation
import CEmbeddedCLIPS

/// A Swift-native interface to the CLIPS expert-system engine.
///
/// Each `CLIPSEngine` instance owns its own CLIPS environment and runs
/// all operations on a private serial queue, so **multiple engines can
/// coexist and run independently** — even concurrently from different
/// threads.
///
/// ## Quick start
///
/// ```swift
/// let engine = CLIPSEngine()
///
/// // 1. Define a template
/// try engine.defineTemplate("sensor", slots: [
///     .slot("type"),
///     .slot("value"),
/// ])
///
/// // 2. Inject facts from Swift data
/// try engine.assertFact("sensor", slots: [
///     "type":  .symbol("temperature"),
///     "value": 98.6,
/// ])
///
/// // 3. Add a rule
/// try engine.defineRule("""
///     (defrule high-temp
///         (sensor (type temperature) (value ?v&:(> ?v 100)))
///         =>
///         (printout t "ALERT: temp is " ?v crlf))
///     """)
///
/// // 4. Run and capture output
/// engine.reset()
/// try engine.assertFact("sensor", slots: ["type": .symbol("temperature"), "value": 105.0])
/// let output = engine.run()
/// print(output) // "ALERT: temp is 105.0"
///
/// // 5. Evaluate expressions and get typed results
/// let sum = try engine.evaluate("(+ 10 20)")
/// print(sum.intValue!) // 30
/// ```
///
/// ## Multiple engines
///
/// ```swift
/// let weatherEngine = CLIPSEngine()
/// let inventoryEngine = CLIPSEngine()
///
/// // Each engine has its own facts, rules, and environment.
/// // They can run concurrently without interfering.
/// DispatchQueue.global().async {
///     try? weatherEngine.assertFact("temp", values: [72])
///     weatherEngine.run()
/// }
/// DispatchQueue.global().async {
///     try? inventoryEngine.assertFact("stock", values: [.symbol("widget"), 50])
///     inventoryEngine.run()
/// }
/// ```
///
/// ## Lifecycle
///
/// The engine is ready immediately after `init()`. Call ``reset()`` to clear
/// facts while keeping templates and rules. Call ``clear()`` to wipe
/// everything. The engine is destroyed automatically on `deinit`.
public final class CLIPSEngine: @unchecked Sendable {

    /// The private serial queue that serializes all access to this engine's
    /// CLIPS environment, ensuring thread safety.
    private let queue: DispatchQueue

    /// Pointer to the C-level CLIPSInstance (environment + output buffer).
    private var instance: UnsafeMutablePointer<CLIPSInstance>?

    // MARK: - Lifecycle

    /// Creates and initializes a new, independent CLIPS engine.
    ///
    /// Each engine gets its own CLIPS environment and serial dispatch queue.
    /// You can create as many engines as you need.
    ///
    /// - Parameter label: An optional label for the engine's dispatch queue,
    ///   useful for debugging. Defaults to a unique identifier.
    public init(label: String? = nil) {
        let queueLabel = label ?? "com.clips.engine.\(UUID().uuidString)"
        self.queue = DispatchQueue(label: queueLabel)
        self.instance = clips_instance_create()
    }

    /// Creates a CLIPS engine and loads constructs from a `.clp` file.
    ///
    /// - Parameters:
    ///   - path: Absolute path to a `.clp` file containing templates,
    ///     rules, or other CLIPS constructs.
    ///   - label: Optional dispatch queue label.
    /// - Throws: ``CLIPSError/fileOperationFailed(path:detail:)`` if the file
    ///   cannot be loaded.
    public init(loadingFileAt path: String, label: String? = nil) throws {
        let queueLabel = label ?? "com.clips.engine.\(UUID().uuidString)"
        self.queue = DispatchQueue(label: queueLabel)
        self.instance = clips_instance_create()
        let result = sync { inst in
            String(cString: clips_instance_load_environment(inst, path))
        }
        if result.contains("Failed") {
            clips_instance_destroy(instance)
            instance = nil
            throw CLIPSError.fileOperationFailed(path: path, detail: "Could not load .clp file.")
        }
    }

    deinit {
        if let inst = instance {
            clips_instance_destroy(inst)
            instance = nil
        }
    }

    // MARK: - Private queue helpers

    /// Executes a closure synchronously on this engine's serial queue,
    /// passing the C instance pointer. Throws ``CLIPSError/engineNotReady``
    /// if the instance is nil.
    private func sync<T>(_ work: (UnsafeMutablePointer<CLIPSInstance>) -> T) -> T {
        return queue.sync {
            guard let inst = self.instance else {
                fatalError("CLIPSEngine used after being destroyed.")
            }
            return work(inst)
        }
    }

    /// Throwing variant of sync.
    private func syncThrowing<T>(_ work: (UnsafeMutablePointer<CLIPSInstance>) throws -> T) throws -> T {
        return try queue.sync {
            guard let inst = self.instance else {
                throw CLIPSError.engineNotReady
            }
            return try work(inst)
        }
    }

    // MARK: - Environment

    /// Resets the engine: retracts all facts and reasserts `initial-fact`,
    /// but keeps all templates, rules, and globals.
    public func reset() {
        sync { inst in clips_instance_reset(inst) }
    }

    /// Clears the engine completely: removes all templates, rules, globals,
    /// and facts. The engine returns to a blank state.
    public func clear() {
        sync { inst in clips_instance_clear(inst) }
    }

    // MARK: - Templates

    /// Defines a CLIPS deftemplate from raw CLIPS syntax.
    ///
    /// ```swift
    /// try engine.defineTemplate(raw: "(deftemplate person (slot name) (slot age))")
    /// ```
    ///
    /// - Parameter definition: A complete `(deftemplate …)` string.
    /// - Throws: ``CLIPSError/buildFailed(construct:)``
    public func defineTemplate(raw definition: String) throws {
        try build(definition)
    }

    /// Defines a CLIPS deftemplate using Swift parameters.
    ///
    /// ```swift
    /// try engine.defineTemplate("sensor", slots: [
    ///     .slot("type"),
    ///     .slot("value"),
    ///     .multislot("readings"),
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - name: The template name.
    ///   - slots: One or more slot definitions.
    /// - Throws: ``CLIPSError/buildFailed(construct:)``
    public func defineTemplate(_ name: String, slots: [SlotDefinition]) throws {
        let slotStrings = slots.map { $0.clipsRepresentation }
        let construct = "(deftemplate \(name) \(slotStrings.joined(separator: " ")))"
        try build(construct)
    }

    // MARK: - Facts (injection)

    /// Asserts a fact using raw CLIPS syntax.
    ///
    /// ```swift
    /// try engine.assertFact(raw: "(person (name \"Alice\") (age 30))")
    /// ```
    ///
    /// - Parameter fact: A CLIPS fact string **without** the outer `(assert …)`.
    /// - Throws: ``CLIPSError/assertionFailed(fact:)``
    @discardableResult
    public func assertFact(raw fact: String) throws -> String {
        return try syncThrowing { inst in
            let result = String(cString: clips_instance_assert_fact(inst, fact))
            if result.contains("Failed") {
                throw CLIPSError.assertionFailed(fact: fact)
            }
            return result
        }
    }

    /// Asserts a templated fact from a Swift dictionary.
    ///
    /// This is the easiest way to inject structured data into CLIPS:
    ///
    /// ```swift
    /// try engine.assertFact("sensor", slots: [
    ///     "type":  .symbol("temperature"),
    ///     "value": 98.6,
    ///     "label": "Main sensor",
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - template: The deftemplate name.
    ///   - slots: Slot name → value pairs.
    /// - Throws: ``CLIPSError/assertionFailed(fact:)``
    @discardableResult
    public func assertFact(_ template: String, slots: [String: CLIPSValue]) throws -> String {
        let slotStrings = slots.map { "(\($0.key) \($0.value.clipsRepresentation))" }
        let fact = "(\(template) \(slotStrings.joined(separator: " ")))"
        return try assertFact(raw: fact)
    }

    /// Asserts a simple ordered fact (no template).
    ///
    /// ```swift
    /// try engine.assertFact("color", values: [.symbol("red")])
    /// ```
    ///
    /// - Parameters:
    ///   - relation: The fact relation name.
    ///   - values: Ordered values for the fact.
    /// - Throws: ``CLIPSError/assertionFailed(fact:)``
    @discardableResult
    public func assertFact(_ relation: String, values: [CLIPSValue] = []) throws -> String {
        let valueStrings = values.map { $0.clipsRepresentation }
        let body = ([relation] + valueStrings).joined(separator: " ")
        return try assertFact(raw: "(\(body))")
    }

    /// Retracts (removes) a fact by its index.
    ///
    /// - Parameter index: The fact index (e.g. 0 for `f-0`).
    /// - Throws: ``CLIPSError/factNotFound(index:)``
    public func retractFact(at index: Int) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_retract_fact(inst, Int64(index)))
            if result.contains("not found") {
                throw CLIPSError.factNotFound(index: index)
            }
        }
    }

    /// Returns all current facts as a raw string.
    ///
    /// Each line is formatted as `f-N     (template slot-values…)`.
    public func getAllFacts() -> String {
        return sync { inst in
            String(cString: clips_instance_get_all_facts(inst))
        }
    }

    // MARK: - Rules

    /// Defines a rule from raw CLIPS syntax.
    ///
    /// ```swift
    /// try engine.defineRule("""
    ///     (defrule greet
    ///         (person (name ?n))
    ///         =>
    ///         (printout t "Hello, " ?n "!" crlf))
    ///     """)
    /// ```
    ///
    /// - Parameter definition: A complete `(defrule …)` string.
    /// - Throws: ``CLIPSError/buildFailed(construct:)``
    public func defineRule(_ definition: String) throws {
        try build(definition)
    }

    /// Removes all activations of a rule from the agenda.
    ///
    /// - Parameter name: The rule name.
    /// - Throws: ``CLIPSError/ruleNotFound(name:)``
    public func removeRuleFromAgenda(_ name: String) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_clear_rule_from_agenda(inst, name))
            if result.contains("not found") {
                throw CLIPSError.ruleNotFound(name: name)
            }
        }
    }

    // MARK: - Execution

    /// Runs the CLIPS inference engine.
    ///
    /// Fires rules on the agenda and returns any text that rules printed
    /// via `(printout t …)`.
    ///
    /// - Parameter limit: Maximum number of rules to fire. Pass `-1` (default)
    ///   to run until the agenda is empty.
    /// - Returns: Text output produced by rule actions during execution.
    @discardableResult
    public func run(limit: Int = -1) -> String {
        return sync { inst in
            String(cString: clips_instance_run(inst, Int64(limit)))
        }
    }

    /// Halts rule execution. This is safe to call from any thread.
    public func halt() {
        // Halt is safe to call from another thread — it sets a flag
        // that the engine checks between rule firings.
        if let inst = instance {
            clips_instance_halt(inst)
        }
    }

    /// Returns the current agenda (pending rule activations) as a string.
    public func getAgenda() -> String {
        return sync { inst in
            String(cString: clips_instance_get_agenda(inst))
        }
    }

    // MARK: - Expression evaluation

    /// Evaluates a CLIPS expression and returns the result as a ``CLIPSValue``.
    ///
    /// ```swift
    /// let sum  = try engine.evaluate("(+ 10 20)")        // .integer(30)
    /// let name = try engine.evaluate("(str-cat \"A\" \"B\")") // .string("AB")
    /// let ok   = try engine.evaluate("(> 5 3)")          // .boolean(true)
    /// ```
    ///
    /// - Parameter expression: A CLIPS expression to evaluate.
    /// - Returns: The result as a typed ``CLIPSValue``.
    /// - Throws: ``CLIPSError/evaluationFailed(expression:)``
    public func evaluate(_ expression: String) throws -> CLIPSValue {
        return try syncThrowing { inst in
            let raw = String(cString: clips_instance_evaluate(inst, expression))
            if raw.hasPrefix("Error evaluating") {
                throw CLIPSError.evaluationFailed(expression: expression)
            }
            return CLIPSValue.parse(raw)
        }
    }

    // MARK: - Globals

    /// Defines a CLIPS global variable.
    ///
    /// ```swift
    /// try engine.defineGlobal("threshold", value: 100)
    /// try engine.defineGlobal("name", value: "Alice")
    /// try engine.defineGlobal("status", value: .symbol("active"))
    /// ```
    ///
    /// - Parameters:
    ///   - name: The global name (without `?*…*` delimiters).
    ///   - value: The initial value.
    /// - Throws: ``CLIPSError/buildFailed(construct:)``
    public func defineGlobal(_ name: String, value: CLIPSValue) throws {
        let construct = "(defglobal ?*\(name)* = \(value.clipsRepresentation))"
        try build(construct)
    }

    /// Reads the current value of a CLIPS global variable.
    ///
    /// - Parameter name: The global name (without `?*…*` delimiters).
    /// - Returns: The current value.
    /// - Throws: ``CLIPSError/globalNotFound(name:)``
    public func getGlobal(_ name: String) throws -> CLIPSValue {
        return try syncThrowing { inst in
            let raw = String(cString: clips_instance_get_global(inst, name))
            if raw.contains("Global not found") {
                throw CLIPSError.globalNotFound(name: name)
            }
            return CLIPSValue.parse(raw)
        }
    }

    /// Sets a CLIPS global variable to a new value.
    ///
    /// - Parameters:
    ///   - name: The global name (without `?*…*` delimiters).
    ///   - value: The new value.
    /// - Throws: ``CLIPSError/globalNotFound(name:)``
    public func setGlobal(_ name: String, value: CLIPSValue) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_set_global(inst, name, value.clipsRepresentation))
            if result.contains("Global not found") {
                throw CLIPSError.globalNotFound(name: name)
            }
        }
    }

    // MARK: - Build (general purpose)

    /// Compiles any CLIPS construct (deftemplate, defrule, defglobal, etc.).
    ///
    /// Most users should prefer the typed helpers (``defineTemplate(_:slots:)``,
    /// ``defineRule(_:)``, ``defineGlobal(_:value:)``). Use `build` when you
    /// have a raw CLIPS string that doesn't fit those categories.
    ///
    /// - Parameter construct: A complete CLIPS construct string.
    /// - Throws: ``CLIPSError/buildFailed(construct:)``
    public func build(_ construct: String) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_build(inst, construct))
            if result.contains("failed") || result.contains("Failed") {
                throw CLIPSError.buildFailed(construct: construct)
            }
        }
    }

    // MARK: - Persistence

    /// Saves all current facts to a file.
    public func saveFacts(to path: String) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_save_facts(inst, path))
            if result.contains("Failed") {
                throw CLIPSError.fileOperationFailed(path: path, detail: "Could not save facts.")
            }
        }
    }

    /// Loads facts from a file, adding them to the current environment.
    public func loadFacts(from path: String) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_load_facts(inst, path))
            if result.contains("Failed") {
                throw CLIPSError.fileOperationFailed(path: path, detail: "Could not load facts.")
            }
        }
    }

    /// Saves all constructs (templates, rules, globals) to a file.
    public func saveEnvironment(to path: String) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_save_environment(inst, path))
            if result.contains("Failed") {
                throw CLIPSError.fileOperationFailed(path: path, detail: "Could not save environment.")
            }
        }
    }

    /// Loads constructs from a `.clp` file into the current environment.
    public func loadEnvironment(from path: String) throws {
        try syncThrowing { inst in
            let result = String(cString: clips_instance_load_environment(inst, path))
            if result.contains("Failed") {
                throw CLIPSError.fileOperationFailed(path: path, detail: "Could not load environment.")
            }
        }
    }

    // MARK: - Debugging

    /// Enables or disables a CLIPS watch item.
    ///
    /// Watch items include: `"facts"`, `"rules"`, `"activations"`,
    /// `"compilations"`, `"statistics"`, `"globals"`, `"focus"`.
    public func setWatch(_ item: String, enabled: Bool) {
        sync { inst in
            clips_instance_enable_watch(inst, item, enabled ? 1 : 0)
        }
    }
}
