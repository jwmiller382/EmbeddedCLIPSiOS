import XCTest
import CEmbeddedCLIPS

final class EmbeddedCLIPSiOSTests: XCTestCase {

    var inst: UnsafeMutablePointer<CLIPSInstance>!

    override func setUp() {
        super.setUp()
        inst = clips_instance_create()
    }

    override func tearDown() {
        if inst != nil {
            clips_instance_destroy(inst)
            inst = nil
        }
        super.tearDown()
    }

    // MARK: - Lifecycle

    func testCreateInstance() {
        XCTAssertEqual(clips_instance_is_valid(inst), 1)
    }

    func testDestroyInstance() {
        clips_instance_destroy(inst)
        inst = nil
    }

    func testResetInstance() {
        let result = String(cString: clips_instance_reset(inst))
        XCTAssertEqual(result, "Environment reset.")
    }

    func testClearInstance() {
        clips_instance_build(inst, "(deftemplate t1 (slot x))")
        let result = String(cString: clips_instance_clear(inst))
        XCTAssertEqual(result, "Environment cleared.")
    }

    // MARK: - Multiple Instances

    func testTwoIndependentInstances() {
        let inst2 = clips_instance_create()!

        // Define template only in inst1
        clips_instance_build(inst, "(deftemplate color (slot name))")
        clips_instance_assert_fact(inst, "(color (name red))")

        // inst2 should have no facts about color
        let facts1 = String(cString: clips_instance_get_all_facts(inst))
        let facts2 = String(cString: clips_instance_get_all_facts(inst2))

        XCTAssertTrue(facts1.contains("red"))
        XCTAssertFalse(facts2.contains("red"))

        clips_instance_destroy(inst2)
    }

    func testThreeInstancesRunIndependently() {
        let instA = clips_instance_create()!
        let instB = clips_instance_create()!

        clips_instance_build(inst, "(defrule r1 (go) => (printout t \"engine1\"))")
        clips_instance_build(instA, "(defrule r2 (go) => (printout t \"engine2\"))")
        clips_instance_build(instB, "(defrule r3 (go) => (printout t \"engine3\"))")

        clips_instance_reset(inst)
        clips_instance_reset(instA)
        clips_instance_reset(instB)

        clips_instance_assert_fact(inst, "(go)")
        clips_instance_assert_fact(instA, "(go)")
        clips_instance_assert_fact(instB, "(go)")

        let out1 = String(cString: clips_instance_run(inst, -1))
        let out2 = String(cString: clips_instance_run(instA, -1))
        let out3 = String(cString: clips_instance_run(instB, -1))

        XCTAssertTrue(out1.contains("engine1"))
        XCTAssertTrue(out2.contains("engine2"))
        XCTAssertTrue(out3.contains("engine3"))

        XCTAssertFalse(out1.contains("engine2"))
        XCTAssertFalse(out2.contains("engine1"))

        clips_instance_destroy(instA)
        clips_instance_destroy(instB)
    }

    // MARK: - Facts

    func testAssertFact() {
        let result = String(cString: clips_instance_assert_fact(inst, "(color red)"))
        XCTAssertTrue(result.contains("Fact asserted"))
    }

    func testAssertInvalidFact() {
        let result = String(cString: clips_instance_assert_fact(inst, "(bad-template (slot x))"))
        XCTAssertTrue(result.contains("Failed"))
    }

    func testRetractFact() {
        clips_instance_reset(inst)
        clips_instance_assert_fact(inst, "(animal dog)")
        let result = String(cString: clips_instance_retract_fact(inst, 1))
        XCTAssertTrue(result.contains("Fact retracted: 1"))
    }

    func testRetractNonexistentFact() {
        clips_instance_reset(inst)
        let result = String(cString: clips_instance_retract_fact(inst, 999))
        XCTAssertTrue(result.contains("Fact not found: 999"))
    }

    func testGetAllFacts() {
        clips_instance_reset(inst)
        clips_instance_assert_fact(inst, "(fruit apple)")
        let facts = String(cString: clips_instance_get_all_facts(inst))
        XCTAssertTrue(facts.contains("apple"))
    }

    // MARK: - Templates & Rules

    func testDefineTemplate() {
        let result = String(cString: clips_instance_define_template(inst,
            "(deftemplate student (slot name) (slot grade))"))
        XCTAssertTrue(result.contains("successfully"))
    }

    func testDefineRule() {
        clips_instance_build(inst, "(deftemplate person (slot name))")
        let result = String(cString: clips_instance_define_rule(inst,
            "(defrule greet (person (name ?n)) => (printout t \"Hi \" ?n crlf))"))
        XCTAssertTrue(result.contains("successfully"))
    }

    // MARK: - Run

    func testRunFiresRule() {
        clips_instance_build(inst, "(defrule say-hello (greeting) => (printout t \"Hello World\"))")
        clips_instance_reset(inst)
        clips_instance_assert_fact(inst, "(greeting)")
        let output = String(cString: clips_instance_run(inst, -1))
        XCTAssertTrue(output.contains("Hello World"))
    }

    // MARK: - Globals

    func testDefineAndGetGlobal() {
        clips_instance_build(inst, "(defglobal ?*counter* = 10)")
        let val = String(cString: clips_instance_get_global(inst, "counter"))
        XCTAssertEqual(val, "10")
    }

    func testSetGlobal() {
        clips_instance_build(inst, "(defglobal ?*score* = 0)")
        clips_instance_set_global(inst, "score", "100")
        let val = String(cString: clips_instance_get_global(inst, "score"))
        XCTAssertEqual(val, "100")
    }

    // MARK: - Evaluate

    func testEvaluateArithmetic() {
        let result = String(cString: clips_instance_evaluate(inst, "(+ 2 3)"))
        XCTAssertEqual(result, "5")
    }

    func testEvaluateInvalid() {
        let result = String(cString: clips_instance_evaluate(inst, "(unknown-func)"))
        XCTAssertTrue(result.contains("Error evaluating"))
    }

    // MARK: - Build

    func testBuildValid() {
        let result = String(cString: clips_instance_build(inst, "(deftemplate item (slot id))"))
        XCTAssertEqual(result, "Build successful.")
    }

    func testBuildInvalid() {
        let result = String(cString: clips_instance_build(inst, "(not-a-construct)"))
        XCTAssertEqual(result, "Build failed.")
    }

    // MARK: - Save / Load

    func testSaveAndLoadFacts() {
        let path = NSTemporaryDirectory() + "clips_c_test_facts.clp"
        defer { try? FileManager.default.removeItem(atPath: path) }

        clips_instance_reset(inst)
        clips_instance_assert_fact(inst, "(color red)")
        clips_instance_save_facts(inst, path)

        clips_instance_clear(inst)
        clips_instance_reset(inst)
        clips_instance_load_facts(inst, path)

        let facts = String(cString: clips_instance_get_all_facts(inst))
        XCTAssertTrue(facts.contains("red"))
    }

    // MARK: - Integration

    func testFullWorkflow() {
        clips_instance_build(inst, "(deftemplate employee (slot name) (slot department))")
        clips_instance_build(inst, """
            (defrule welcome
                (employee (name ?n) (department engineering))
                =>
                (printout t "Welcome " ?n "!" crlf))
            """)
        clips_instance_reset(inst)
        clips_instance_assert_fact(inst, "(employee (name Alice) (department engineering))")
        clips_instance_assert_fact(inst, "(employee (name Bob) (department sales))")
        let output = String(cString: clips_instance_run(inst, -1))
        XCTAssertTrue(output.contains("Welcome Alice!"))
        XCTAssertFalse(output.contains("Bob"))
    }
}
