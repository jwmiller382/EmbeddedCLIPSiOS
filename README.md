# EmbeddedCLIPSiOS

A Swift Package that embeds the [CLIPS](http://www.clipsrules.net/) expert-system engine (v6.40) for iOS and macOS. It provides a clean, type-safe Swift API for defining templates, injecting facts, running rules, and reading results -- all without touching C strings or pointers.

Each `CLIPSEngine` instance owns its own CLIPS environment and runs on a private serial queue, so **multiple engines can run concurrently** on different threads.

## Requirements

- iOS 13+ / macOS 10.15+
- Swift 6.0+
- Xcode 16+

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jwmiller382/EmbeddedCLIPSiOS.git", from: "1.0.0"),
]
```

Then add `"EmbeddedCLIPSiOS"` to the target that needs it:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "EmbeddedCLIPSiOS", package: "EmbeddedCLIPSiOS"),
    ]
),
```

Or in Xcode: **File > Add Package Dependencies** and paste the repository URL.

## Quick Start

```swift
import CLIPSEngine

let engine = CLIPSEngine()

// 1. Define a template
try engine.defineTemplate("sensor", slots: [
    .slot("type"),
    .slot("value"),
])

// 2. Inject facts from Swift data
try engine.assertFact("sensor", slots: [
    "type":  .symbol("temperature"),
    "value": 98.6,
])

// 3. Define a rule
try engine.defineRule("""
    (defrule high-temp
        (sensor (type temperature) (value ?v&:(> ?v 100)))
        =>
        (printout t "ALERT: temp is " ?v crlf))
    """)

// 4. Run and capture output
engine.reset()
try engine.assertFact("sensor", slots: [
    "type":  .symbol("temperature"),
    "value": 105.0,
])
let output = engine.run()
print(output) // "ALERT: temp is 105.0"

// 5. Evaluate expressions and get typed results
let sum = try engine.evaluate("(+ 10 20)")
print(sum.intValue!) // 30
```

## API Reference

### CLIPSEngine

The main entry point. Each instance is independent and thread-safe.

```swift
let engine = CLIPSEngine()                          // blank engine
let engine = CLIPSEngine(label: "weather")          // with a debug label
let engine = try CLIPSEngine(loadingFileAt: path)   // load a .clp file
```

#### Lifecycle

| Method | Description |
|--------|-------------|
| `reset()` | Retracts all facts, keeps templates/rules/globals |
| `clear()` | Removes everything -- back to blank state |

#### Defining Templates

Build templates from Swift -- no CLIPS syntax needed:

```swift
try engine.defineTemplate("person", slots: [
    .slot("name"),
    .slot("age"),
    .multislot("hobbies"),
    .slot("active", defaultValue: true),
])
```

Or use raw CLIPS syntax:

```swift
try engine.defineTemplate(raw: "(deftemplate person (slot name) (slot age))")
```

#### Injecting Facts

**Dictionary style** (easiest for structured data):

```swift
try engine.assertFact("person", slots: [
    "name": "Alice",
    "age":  30,
])
```

**Ordered facts** (no template needed):

```swift
try engine.assertFact("color", values: [.symbol("red")])
```

**Raw CLIPS syntax**:

```swift
try engine.assertFact(raw: "(person (name \"Alice\") (age 30))")
```

**Retracting facts**:

```swift
try engine.retractFact(at: 1)  // retract fact f-1
```

**Reading facts back**:

```swift
let allFacts = engine.getAllFacts()  // raw string of all facts
```

#### Defining Rules

```swift
try engine.defineRule("""
    (defrule greet
        (person (name ?n))
        =>
        (printout t "Hello, " ?n "!" crlf))
    """)
```

#### Running the Engine

```swift
let output = engine.run()           // run until agenda is empty
let output = engine.run(limit: 5)   // fire at most 5 rules
engine.halt()                       // stop from another thread
```

The return value contains any text rules printed via `(printout t ...)`.

#### Evaluating Expressions

Get typed results back from CLIPS:

```swift
let sum  = try engine.evaluate("(+ 10 20)")          // .integer(30)
let name = try engine.evaluate("(str-cat \"A\" \"B\")")  // .string("AB")
let ok   = try engine.evaluate("(> 5 3)")             // .boolean(true)
let pi   = try engine.evaluate("(/ 22.0 7.0)")        // .float(3.142857...)
```

#### Global Variables

```swift
try engine.defineGlobal("threshold", value: 100)
try engine.setGlobal("threshold", value: 200)
let val = try engine.getGlobal("threshold")  // .integer(200)
```

> Note: `reset()` restores globals to their initial values. Set globals **after** calling `reset()`.

#### Persistence

```swift
try engine.saveFacts(to: path)
try engine.loadFacts(from: path)
try engine.saveEnvironment(to: path)
try engine.loadEnvironment(from: path)
```

#### General Build

Compile any CLIPS construct:

```swift
try engine.build("(deffunction double (?x) (* ?x 2))")
```

### CLIPSValue

Type-safe representation of CLIPS values. Supports Swift literal syntax:

```swift
let s: CLIPSValue = "hello"        // .string("hello")
let n: CLIPSValue = 42             // .integer(42)
let f: CLIPSValue = 3.14           // .float(3.14)
let b: CLIPSValue = true           // .boolean(true)
let sym = CLIPSValue.symbol("ok")  // CLIPS symbol (unquoted)
```

Read values back with typed accessors:

```swift
result.stringValue   // String?
result.intValue      // Int?
result.floatValue    // Double?
result.boolValue     // Bool?
result.symbolValue   // String?
```

### SlotDefinition

Used when defining templates:

```swift
.slot("name")                          // single-value slot
.slot("retries", defaultValue: 3)      // with default
.multislot("items")                    // multi-value slot
```

### CLIPSError

All throwing methods report errors through `CLIPSError`:

```swift
do {
    try engine.assertFact("bad", slots: ["x": 1])
} catch CLIPSError.assertionFailed(let fact) {
    print("Bad fact: \(fact)")
} catch CLIPSError.buildFailed(let construct) {
    print("Bad construct: \(construct)")
} catch CLIPSError.evaluationFailed(let expr) {
    print("Bad expression: \(expr)")
}
```

| Case | When |
|------|------|
| `.engineNotReady` | Engine was destroyed or failed to init |
| `.buildFailed(construct:)` | Template, rule, or other construct failed to compile |
| `.assertionFailed(fact:)` | Fact assertion rejected |
| `.evaluationFailed(expression:)` | Expression could not be parsed or executed |
| `.factNotFound(index:)` | No fact at that index |
| `.globalNotFound(name:)` | No defglobal with that name |
| `.ruleNotFound(name:)` | No defrule with that name |
| `.fileOperationFailed(path:detail:)` | Save or load failed |

## Multiple Engines

Each engine is fully isolated -- its own environment, facts, rules, and thread queue:

```swift
let weatherEngine   = CLIPSEngine(label: "weather")
let inventoryEngine = CLIPSEngine(label: "inventory")

// Run concurrently on different threads
DispatchQueue.global().async {
    try? weatherEngine.assertFact("temp", values: [72])
    weatherEngine.run()
}
DispatchQueue.global().async {
    try? inventoryEngine.assertFact("stock", values: [.symbol("widget"), 50])
    inventoryEngine.run()
}
```

## End-to-End Example: Sensor Alert System

```swift
import CLIPSEngine

let engine = CLIPSEngine()

// Define the domain model
try engine.defineTemplate("sensor", slots: [
    .slot("id"),
    .slot("type"),
    .slot("value"),
])

try engine.defineTemplate("alert", slots: [
    .slot("sensor_id"),
    .slot("message"),
])

// Define alert rules
try engine.defineRule("""
    (defrule high-temperature
        (sensor (id ?id) (type temperature) (value ?v&:(> ?v 100)))
        =>
        (assert (alert (sensor_id ?id)
                       (message "High temperature detected")))
        (printout t "ALERT sensor " ?id ": temp=" ?v crlf))
    """)

// Inject sensor readings from your app
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

// Run the rules
let output = engine.run()
// output contains:
//   "ALERT sensor 2: temp=105.3\nALERT sensor 4: temp=110.0\n"

// Check generated alert facts
let facts = engine.getAllFacts()
// Contains (alert (sensor_id 2) (message "High temperature detected"))
// and     (alert (sensor_id 4) (message "High temperature detected"))
```

## Testing

```bash
swift test
```

82 tests covering: environment lifecycle, fact injection, templates, rules, execution, expression evaluation, globals, persistence, multiple engines, and concurrent execution.

## License

CLIPS is provided under its original license by Gary Riley / NASA. See the CLIPS source files for details. The Swift wrapper code in this package is available under the MIT License.
