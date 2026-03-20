import XCTest
@testable import CLIPSEngine

final class CLIPSEngineTests: XCTestCase {

    var engine: CLIPSEngine!

    override func setUp() {
        super.setUp()
        engine = CLIPSEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // =========================================================================
    // MARK: - Lifecycle
    // =========================================================================

    func testEngineInitializes() {
        // Engine is created in setUp; just verify it doesn't crash
        XCTAssertNotNil(engine)
    }

    func testResetDoesNotThrow() {
        engine.reset()
    }

    func testClearRemovesConstructs() throws {
        try engine.defineTemplate("thing", slots: [.slot("x")])
        engine.clear()
        // Template is gone, so asserting a templated fact should fail
        XCTAssertThrowsError(try engine.assertFact("thing", slots: ["x": 1]))
    }

    // =========================================================================
    // MARK: - Templates (defineTemplate)
    // =========================================================================

    func testDefineTemplateRaw() throws {
        try engine.defineTemplate(raw: "(deftemplate book (slot title) (slot author))")
        try engine.assertFact("book", slots: ["title": "Dune", "author": "Herbert"])
    }

    func testDefineTemplateWithSlots() throws {
        try engine.defineTemplate("sensor", slots: [
            .slot("type"),
            .slot("value"),
        ])
        try engine.assertFact("sensor", slots: [
            "type":  .symbol("temperature"),
            "value": 98.6,
        ])
    }

    func testDefineTemplateWithMultislot() throws {
        try engine.defineTemplate("order", slots: [
            .slot("id"),
            .multislot("items"),
        ])
        // Just verify it built without error
    }

    func testDefineTemplateWithDefaultValue() throws {
        try engine.defineTemplate("config", slots: [
            .slot("debug", defaultValue: .boolean(false)),
            .slot("retries", defaultValue: 3),
        ])
        // Assert with defaults
        engine.reset()
        try engine.assertFact(raw: "(config)")
    }

    func testDefineInvalidTemplateThrows() {
        XCTAssertThrowsError(try engine.defineTemplate(raw: "(deftemplate)")) { error in
            guard case CLIPSError.buildFailed = error else {
                return XCTFail("Expected buildFailed, got \(error)")
            }
        }
    }

    // =========================================================================
    // MARK: - Fact injection: assertFact with dictionary
    // =========================================================================

    func testAssertFactWithStringValue() throws {
        try engine.defineTemplate("person", slots: [.slot("name"), .slot("city")])
        try engine.assertFact("person", slots: [
            "name": "Alice",         // String literal
            "city": "Portland",
        ])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("Alice"))
        XCTAssertTrue(facts.contains("Portland"))
    }

    func testAssertFactWithIntegerValue() throws {
        try engine.defineTemplate("counter", slots: [.slot("n")])
        try engine.assertFact("counter", slots: ["n": 42])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("42"))
    }

    func testAssertFactWithFloatValue() throws {
        try engine.defineTemplate("measurement", slots: [.slot("temp")])
        try engine.assertFact("measurement", slots: ["temp": 36.6])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("36.6"))
    }

    func testAssertFactWithSymbolValue() throws {
        try engine.defineTemplate("status", slots: [.slot("level")])
        try engine.assertFact("status", slots: ["level": .symbol("critical")])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("critical"))
    }

    func testAssertFactWithBooleanValue() throws {
        try engine.defineTemplate("flag", slots: [.slot("active")])
        try engine.assertFact("flag", slots: ["active": true])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("TRUE"))
    }

    func testAssertFactWithMixedTypes() throws {
        try engine.defineTemplate("record", slots: [
            .slot("name"), .slot("age"), .slot("score"), .slot("active"),
        ])
        try engine.assertFact("record", slots: [
            "name":   "Bob",
            "age":    25,
            "score":  99.5,
            "active": true,
        ])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("Bob"))
        XCTAssertTrue(facts.contains("25"))
    }

    func testAssertInvalidFactThrows() {
        XCTAssertThrowsError(
            try engine.assertFact("nonexistent", slots: ["x": 1])
        ) { error in
            guard case CLIPSError.assertionFailed = error else {
                return XCTFail("Expected assertionFailed, got \(error)")
            }
        }
    }

    // =========================================================================
    // MARK: - Fact injection: ordered facts
    // =========================================================================

    func testAssertOrderedFact() throws {
        try engine.assertFact("color", values: [.symbol("red")])
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("red"))
    }

    func testAssertOrderedFactNoValues() throws {
        try engine.assertFact("trigger")
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("trigger"))
    }

    // =========================================================================
    // MARK: - Fact injection: raw syntax
    // =========================================================================

    func testAssertFactRaw() throws {
        try engine.defineTemplate(raw: "(deftemplate car (slot make) (slot year))")
        try engine.assertFact(raw: "(car (make Ford) (year 2024))")
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("Ford"))
    }

    // =========================================================================
    // MARK: - Retract facts
    // =========================================================================

    func testRetractFact() throws {
        engine.reset()
        try engine.assertFact("item", values: [.symbol("apple")])
        try engine.retractFact(at: 1)
        let facts = engine.getAllFacts()
        XCTAssertFalse(facts.contains("apple"))
    }

    func testRetractNonexistentFactThrows() {
        engine.reset()
        XCTAssertThrowsError(try engine.retractFact(at: 999)) { error in
            guard case CLIPSError.factNotFound(let idx) = error else {
                return XCTFail("Expected factNotFound, got \(error)")
            }
            XCTAssertEqual(idx, 999)
        }
    }

    // =========================================================================
    // MARK: - Rules & execution with result capture
    // =========================================================================

    func testDefineAndRunRule() throws {
        try engine.defineTemplate("greeting", slots: [.slot("name")])
        try engine.defineRule("""
            (defrule say-hi
                (greeting (name ?n))
                =>
                (printout t "Hello, " ?n "!" crlf))
            """)

        engine.reset()
        try engine.assertFact("greeting", slots: ["name": .symbol("Alice")])
        let output = engine.run()
        XCTAssertTrue(output.contains("Hello, Alice!"))
    }

    func testRunReturnsEmptyWhenNoRulesFire() throws {
        engine.reset()
        let output = engine.run()
        XCTAssertTrue(output.isEmpty)
    }

    func testRunWithLimit() throws {
        try engine.build("(defrule r1 (a) => (printout t \"A\"))")
        try engine.build("(defrule r2 (b) => (printout t \"B\"))")
        engine.reset()
        try engine.assertFact("a")
        try engine.assertFact("b")
        let output = engine.run(limit: 1)
        // Only one rule should fire
        let both = output.contains("A") && output.contains("B")
        XCTAssertFalse(both)
    }

    func testDefineInvalidRuleThrows() {
        XCTAssertThrowsError(try engine.defineRule("(defrule)")) { error in
            guard case CLIPSError.buildFailed = error else {
                return XCTFail("Expected buildFailed")
            }
        }
    }

    // =========================================================================
    // MARK: - Evaluate expressions (result extraction)
    // =========================================================================

    func testEvaluateInteger() throws {
        let result = try engine.evaluate("(+ 10 20)")
        XCTAssertEqual(result, .integer(30))
        XCTAssertEqual(result.intValue, 30)
    }

    func testEvaluateFloat() throws {
        let result = try engine.evaluate("(/ 10.0 3.0)")
        guard case .float(let val) = result else {
            return XCTFail("Expected float")
        }
        XCTAssertEqual(val, 10.0 / 3.0, accuracy: 0.001)
    }

    func testEvaluateString() throws {
        let result = try engine.evaluate("(str-cat \"hello\" \" \" \"world\")")
        XCTAssertEqual(result, .string("hello world"))
        XCTAssertEqual(result.stringValue, "hello world")
    }

    func testEvaluateBooleanTrue() throws {
        let result = try engine.evaluate("(> 5 3)")
        XCTAssertEqual(result, .boolean(true))
        XCTAssertEqual(result.boolValue, true)
    }

    func testEvaluateBooleanFalse() throws {
        let result = try engine.evaluate("(< 5 3)")
        XCTAssertEqual(result, .boolean(false))
        XCTAssertEqual(result.boolValue, false)
    }

    func testEvaluateInvalidExpressionThrows() {
        XCTAssertThrowsError(try engine.evaluate("(unknown-func)")) { error in
            guard case CLIPSError.evaluationFailed = error else {
                return XCTFail("Expected evaluationFailed")
            }
        }
    }

    // =========================================================================
    // MARK: - Globals (define, get, set)
    // =========================================================================

    func testDefineAndGetGlobalInteger() throws {
        try engine.defineGlobal("count", value: 42)
        let val = try engine.getGlobal("count")
        XCTAssertEqual(val, .integer(42))
    }

    func testDefineAndGetGlobalString() throws {
        try engine.defineGlobal("name", value: "Alice")
        let val = try engine.getGlobal("name")
        XCTAssertEqual(val, .string("Alice"))
    }

    func testDefineAndGetGlobalFloat() throws {
        try engine.defineGlobal("pi", value: 3.14)
        let val = try engine.getGlobal("pi")
        guard case .float(let f) = val else { return XCTFail("Expected float") }
        XCTAssertEqual(f, 3.14, accuracy: 0.001)
    }

    func testDefineAndGetGlobalSymbol() throws {
        try engine.defineGlobal("status", value: .symbol("active"))
        let val = try engine.getGlobal("status")
        XCTAssertEqual(val.symbolValue ?? val.stringValue, "active")
    }

    func testSetGlobal() throws {
        try engine.defineGlobal("score", value: 0)
        try engine.setGlobal("score", value: 100)
        let val = try engine.getGlobal("score")
        XCTAssertEqual(val, .integer(100))
    }

    func testGetNonexistentGlobalThrows() {
        XCTAssertThrowsError(try engine.getGlobal("missing")) { error in
            guard case CLIPSError.globalNotFound = error else {
                return XCTFail("Expected globalNotFound")
            }
        }
    }

    func testSetNonexistentGlobalThrows() {
        XCTAssertThrowsError(try engine.setGlobal("missing", value: 1)) { error in
            guard case CLIPSError.globalNotFound = error else {
                return XCTFail("Expected globalNotFound")
            }
        }
    }

    // =========================================================================
    // MARK: - Build (general purpose)
    // =========================================================================

    func testBuildValidConstruct() throws {
        try engine.build("(deftemplate widget (slot id))")
    }

    func testBuildInvalidConstructThrows() {
        XCTAssertThrowsError(try engine.build("(not-a-valid-construct)"))
    }

    // =========================================================================
    // MARK: - Agenda
    // =========================================================================

    func testGetAgendaShowsActivation() throws {
        try engine.build("(defrule test-rule (go) => (printout t \"go\"))")
        engine.reset()
        try engine.assertFact("go")
        let agenda = engine.getAgenda()
        XCTAssertTrue(agenda.contains("test-rule"))
    }

    func testRemoveRuleFromAgenda() throws {
        try engine.build("(defrule remove-me (go) => (printout t \"go\"))")
        engine.reset()
        try engine.assertFact("go")
        try engine.removeRuleFromAgenda("remove-me")
        let agenda = engine.getAgenda()
        XCTAssertFalse(agenda.contains("remove-me"))
    }

    func testRemoveNonexistentRuleThrows() {
        XCTAssertThrowsError(try engine.removeRuleFromAgenda("ghost")) { error in
            guard case CLIPSError.ruleNotFound = error else {
                return XCTFail("Expected ruleNotFound")
            }
        }
    }

    // =========================================================================
    // MARK: - Persistence
    // =========================================================================

    func testSaveAndLoadFacts() throws {
        let path = NSTemporaryDirectory() + "clips_swift_test_facts.clp"
        defer { try? FileManager.default.removeItem(atPath: path) }

        engine.reset()
        try engine.assertFact("fruit", values: [.symbol("apple")])
        try engine.assertFact("fruit", values: [.symbol("banana")])
        try engine.saveFacts(to: path)

        engine.clear()
        engine.reset()
        try engine.loadFacts(from: path)

        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("apple"))
        XCTAssertTrue(facts.contains("banana"))
    }

    func testSaveAndLoadEnvironment() throws {
        let path = NSTemporaryDirectory() + "clips_swift_test_env.clp"
        defer { try? FileManager.default.removeItem(atPath: path) }

        try engine.defineTemplate("device", slots: [.slot("id"), .slot("type")])
        try engine.saveEnvironment(to: path)

        engine.clear()
        try engine.loadEnvironment(from: path)

        // Template should be available again
        try engine.assertFact("device", slots: ["id": 1, "type": .symbol("sensor")])
    }

    func testLoadFactsFromBadPathThrows() {
        XCTAssertThrowsError(try engine.loadFacts(from: "/no/such/file.clp")) { error in
            guard case CLIPSError.fileOperationFailed = error else {
                return XCTFail("Expected fileOperationFailed")
            }
        }
    }

    // =========================================================================
    // MARK: - Watch (no-crash smoke test)
    // =========================================================================

    func testSetWatchDoesNotCrash() {
        engine.setWatch("facts", enabled: true)
        engine.setWatch("rules", enabled: true)
        engine.setWatch("facts", enabled: false)
        engine.setWatch("rules", enabled: false)
    }

    // =========================================================================
    // MARK: - CLIPSValue type
    // =========================================================================

    func testCLIPSValueLiterals() {
        let s: CLIPSValue = "hello"
        XCTAssertEqual(s, .string("hello"))

        let i: CLIPSValue = 42
        XCTAssertEqual(i, .integer(42))

        let f: CLIPSValue = 3.14
        XCTAssertEqual(f, .float(3.14))

        let b: CLIPSValue = true
        XCTAssertEqual(b, .boolean(true))
    }

    func testCLIPSValueCLIPSRepresentation() {
        XCTAssertEqual(CLIPSValue.string("hi").clipsRepresentation, "\"hi\"")
        XCTAssertEqual(CLIPSValue.symbol("ok").clipsRepresentation, "ok")
        XCTAssertEqual(CLIPSValue.integer(7).clipsRepresentation, "7")
        XCTAssertEqual(CLIPSValue.boolean(true).clipsRepresentation, "TRUE")
        XCTAssertEqual(CLIPSValue.boolean(false).clipsRepresentation, "FALSE")
    }

    func testCLIPSValueParse() {
        XCTAssertEqual(CLIPSValue.parse("42"), .integer(42))
        XCTAssertEqual(CLIPSValue.parse("3.14"), .float(3.14))
        XCTAssertEqual(CLIPSValue.parse("TRUE"), .boolean(true))
        XCTAssertEqual(CLIPSValue.parse("FALSE"), .boolean(false))
        XCTAssertEqual(CLIPSValue.parse("hello"), .string("hello"))
    }

    func testCLIPSValueTypedAccessors() {
        XCTAssertEqual(CLIPSValue.string("a").stringValue, "a")
        XCTAssertNil(CLIPSValue.string("a").intValue)

        XCTAssertEqual(CLIPSValue.integer(5).intValue, 5)
        XCTAssertNil(CLIPSValue.integer(5).stringValue)

        XCTAssertEqual(CLIPSValue.float(1.5).floatValue, 1.5)
        XCTAssertEqual(CLIPSValue.boolean(true).boolValue, true)
        XCTAssertEqual(CLIPSValue.symbol("x").symbolValue, "x")
    }

    // =========================================================================
    // MARK: - Integration: end-to-end workflows
    // =========================================================================

    /// Demonstrates a complete data-in → rules → results-out workflow.
    func testSensorAlertWorkflow() throws {
        // Define the domain
        try engine.defineTemplate("sensor", slots: [
            .slot("id"),
            .slot("type"),
            .slot("value"),
        ])

        try engine.defineTemplate("alert", slots: [
            .slot("sensor_id"),
            .slot("message"),
        ])

        try engine.defineRule("""
            (defrule high-temperature
                (sensor (id ?id) (type temperature) (value ?v&:(> ?v 100)))
                =>
                (assert (alert (sensor_id ?id) (message "High temperature detected")))
                (printout t "ALERT for sensor " ?id ": temp=" ?v crlf))
            """)

        // Inject sensor readings from "Swift world"
        engine.reset()

        let readings: [(id: Int, type: String, value: Double)] = [
            (1, "temperature", 72.0),
            (2, "temperature", 105.3),
            (3, "humidity",    45.0),
            (4, "temperature", 110.0),
        ]

        for r in readings {
            try engine.assertFact("sensor", slots: [
                "id":    .integer(r.id),
                "type":  .symbol(r.type),
                "value": .float(r.value),
            ])
        }

        // Run rules
        let output = engine.run()

        // Verify rule output
        XCTAssertTrue(output.contains("ALERT for sensor 2"))
        XCTAssertTrue(output.contains("ALERT for sensor 4"))
        XCTAssertFalse(output.contains("sensor 1"))
        XCTAssertFalse(output.contains("sensor 3"))

        // Verify generated alert facts
        let facts = engine.getAllFacts()
        XCTAssertTrue(facts.contains("High temperature detected"))
    }

    /// Demonstrates using globals to parameterize rules.
    func testConfigurableThresholdWorkflow() throws {
        try engine.defineGlobal("threshold", value: 50)

        try engine.build("(deftemplate reading (slot value))")
        try engine.defineRule("""
            (defrule check-threshold
                (reading (value ?v))
                (test (> ?v ?*threshold*))
                =>
                (printout t "OVER:" ?v crlf))
            """)

        // Run with threshold = 50
        engine.reset()
        try engine.assertFact("reading", slots: ["value": 30])
        try engine.assertFact("reading", slots: ["value": 75])
        var output = engine.run()
        XCTAssertTrue(output.contains("OVER:75"))
        XCTAssertFalse(output.contains("OVER:30"))

        // Change threshold to 20 and re-run (set AFTER reset, since reset restores initial values)
        engine.reset()
        try engine.setGlobal("threshold", value: 20)
        try engine.assertFact("reading", slots: ["value": 30])
        try engine.assertFact("reading", slots: ["value": 75])
        output = engine.run()
        XCTAssertTrue(output.contains("OVER:75"))
        XCTAssertTrue(output.contains("OVER:30"))
    }

    /// Demonstrates rules asserting new facts that trigger other rules (chaining).
    func testRuleChainingWorkflow() throws {
        try engine.defineTemplate("order", slots: [.slot("amount")])
        try engine.defineTemplate("discount", slots: [.slot("percent")])
        try engine.defineTemplate("total", slots: [.slot("value")])

        try engine.defineRule("""
            (defrule apply-bulk-discount
                (order (amount ?a&:(> ?a 100)))
                =>
                (assert (discount (percent 10))))
            """)

        try engine.defineRule("""
            (defrule compute-total
                (order (amount ?a))
                (discount (percent ?d))
                =>
                (printout t "Total: " (* ?a (/ (- 100 ?d) 100.0)) crlf))
            """)

        engine.reset()
        try engine.assertFact("order", slots: ["amount": 200])
        let output = engine.run()

        // 200 * 0.90 = 180.0
        XCTAssertTrue(output.contains("180.0"))
    }

    // =========================================================================
    // MARK: - Multiple independent engines
    // =========================================================================

    func testTwoEnginesAreIndependent() throws {
        let engine2 = CLIPSEngine(label: "engine2")

        // Define template only in engine1
        try engine.defineTemplate("color", slots: [.slot("name")])
        try engine.assertFact("color", slots: ["name": .symbol("red")])

        // engine2 knows nothing about "color"
        let facts1 = engine.getAllFacts()
        let facts2 = engine2.getAllFacts()

        XCTAssertTrue(facts1.contains("red"))
        XCTAssertFalse(facts2.contains("red"))
    }

    func testThreeEnginesRunDifferentRules() throws {
        let e1 = CLIPSEngine(label: "e1")
        let e2 = CLIPSEngine(label: "e2")
        let e3 = CLIPSEngine(label: "e3")

        try e1.build("(defrule r (go) => (printout t \"ONE\"))")
        try e2.build("(defrule r (go) => (printout t \"TWO\"))")
        try e3.build("(defrule r (go) => (printout t \"THREE\"))")

        for e in [e1, e2, e3] {
            e.reset()
            try e.assertFact("go")
        }

        let o1 = e1.run()
        let o2 = e2.run()
        let o3 = e3.run()

        XCTAssertTrue(o1.contains("ONE"))
        XCTAssertTrue(o2.contains("TWO"))
        XCTAssertTrue(o3.contains("THREE"))

        XCTAssertFalse(o1.contains("TWO"))
        XCTAssertFalse(o2.contains("ONE"))
    }

    func testEngineGlobalsAreIsolated() throws {
        let e1 = CLIPSEngine(label: "globals-e1")
        let e2 = CLIPSEngine(label: "globals-e2")

        try e1.defineGlobal("x", value: 10)
        try e2.defineGlobal("x", value: 99)

        let v1 = try e1.getGlobal("x")
        let v2 = try e2.getGlobal("x")

        XCTAssertEqual(v1, .integer(10))
        XCTAssertEqual(v2, .integer(99))
    }

    // =========================================================================
    // MARK: - Concurrent execution
    // =========================================================================

    func testConcurrentEnginesOnDifferentThreads() throws {
        let engines = (0..<5).map { CLIPSEngine(label: "concurrent-\($0)") }
        let group = DispatchGroup()
        let results = UnsafeMutableBufferPointer<String>.allocate(capacity: 5)
        defer { results.deallocate() }

        for (i, eng) in engines.enumerated() {
            try eng.build("(defrule r (go) => (printout t \"engine-\(i)\"))")
            eng.reset()
            try eng.assertFact("go")
        }

        for (i, eng) in engines.enumerated() {
            group.enter()
            DispatchQueue.global().async {
                let output = eng.run()
                results[i] = output
                group.leave()
            }
        }

        group.wait()

        for i in 0..<5 {
            XCTAssertTrue(results[i].contains("engine-\(i)"),
                          "Engine \(i) produced: \(results[i])")
        }
    }

    func testConcurrentFactInjectionAndRun() throws {
        let e1 = CLIPSEngine(label: "conc-facts-1")
        let e2 = CLIPSEngine(label: "conc-facts-2")

        try e1.defineTemplate("num", slots: [.slot("v")])
        try e1.defineRule("""
            (defrule sum-big
                (num (v ?v&:(> ?v 50)))
                =>
                (printout t "BIG:" ?v " "))
            """)

        try e2.defineTemplate("word", slots: [.slot("text")])
        try e2.defineRule("""
            (defrule print-word
                (word (text ?t))
                =>
                (printout t ?t " "))
            """)

        e1.reset()
        e2.reset()

        let group = DispatchGroup()
        var output1 = ""
        var output2 = ""

        group.enter()
        DispatchQueue.global().async {
            for i in stride(from: 10, through: 100, by: 10) {
                try? e1.assertFact("num", slots: ["v": .integer(i)])
            }
            output1 = e1.run()
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            for w in ["alpha", "beta", "gamma"] {
                try? e2.assertFact("word", slots: ["text": .symbol(w)])
            }
            output2 = e2.run()
            group.leave()
        }

        group.wait()

        // Engine 1 should have printed values > 50
        XCTAssertTrue(output1.contains("BIG:60"))
        XCTAssertTrue(output1.contains("BIG:100"))
        XCTAssertFalse(output1.contains("BIG:10 "))

        // Engine 2 should have printed the words
        XCTAssertTrue(output2.contains("alpha"))
        XCTAssertTrue(output2.contains("beta"))
        XCTAssertTrue(output2.contains("gamma"))

        // Neither should leak into the other
        XCTAssertFalse(output1.contains("alpha"))
        XCTAssertFalse(output2.contains("BIG"))
    }

    func testHaltFromAnotherThread() throws {
        // Use a dedicated engine for this test to avoid tearDown races
        let haltEngine = CLIPSEngine(label: "halt-test")

        try haltEngine.build("""
            (defrule loop
                ?f <- (counter ?n&:(< ?n 100000))
                =>
                (retract ?f)
                (assert (counter (+ ?n 1))))
            """)

        haltEngine.reset()
        try haltEngine.assertFact("counter", values: [0])

        // Halt from another thread after a short delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            haltEngine.halt()
        }

        // Run should stop early due to halt
        let _ = haltEngine.run()
        // If we get here without hanging, the test passes
    }

    func testEngineWithLabel() throws {
        let labeled = CLIPSEngine(label: "my.custom.label")
        try labeled.build("(deftemplate widget (slot x))")
        try labeled.assertFact("widget", slots: ["x": 42])
        let facts = labeled.getAllFacts()
        XCTAssertTrue(facts.contains("42"))
    }
}
