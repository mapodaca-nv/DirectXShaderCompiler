// RUN: %dxc -T lib_6_9 -verify %s

// Negative tests for edge cases and unusual inputs for Work Graph Loops
// NOTE: Basic validation errors are in loop_attributes_errors.hlsl
// NOTE: Stage-specific errors are in loop_attributes_stage_check.hlsl
// NOTE: Boundary tests are in loop_attributes_basic.hlsl

struct RECORD { uint data; };

// Test 1: NodeMaxLoopIterations on mesh node (invalid launch mode)
// expected-error@+2{{attribute 'NodeLaunch' must have one of these values: broadcasting,coalescing,thread}}
[Shader("node")]
[NodeLaunch("mesh")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(128,1,1)]
[OutputTopology("triangle")]
void loop_on_mesh_node(
    [MaxRecords(10)] EmptyNodeOutput output,
    out indices uint3 triangles[128],
    out vertices float3 verts[64]) {}

// Test 2: Loop entry node with NodeMaxRecursionDepth
// expected-error@+6{{NodeMaxRecursionDepth is not allowed on loop entry nodes}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NodeMaxRecursionDepth(5)]  // Not allowed with loop attributes
[NumThreads(1,1,1)]
void loop_with_recursion_attribute(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 3: Negative NodeMaxLoopIterations (wraps to large unsigned)
// expected-warning@+5{{attribute 'NodeMaxLoopIterations' must have a uint literal argument}}
// expected-error@+4{{NodeMaxLoopIterations value 4294967196 exceeds maximum of 16777214}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(-100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void negative_loop_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 4: Negative NodeMaxRecordsPerLoopIteration (wraps to large unsigned)
// expected-warning@+6{{attribute 'NodeMaxRecordsPerLoopIteration' must have a uint literal argument}}
// expected-error@+5{{NodeMaxRecordsPerLoopIteration value 4294967286 exceeds maximum of 256}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(-10)]
[NumThreads(1,1,1)]
void negative_records_per_iteration(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 5: Non-literal NodeMaxLoopIterations (constants work, no error expected)
static const uint DYNAMIC_ITERATIONS = 100;
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(DYNAMIC_ITERATIONS)]  // Constants work fine
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void non_literal_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 6: Non-literal NodeMaxRecordsPerLoopIteration (constants work, no error expected)
static const uint DYNAMIC_RECORDS = 10;
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(DYNAMIC_RECORDS)]  // Constants work fine
[NumThreads(1,1,1)]
void non_literal_records(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 7: Multiple NodeMaxLoopIterations attributes (duplicate attributes allowed, last one wins)
// No error expected - duplicate attributes are accepted
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxLoopIterations(200)]  // Duplicate
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void duplicate_loop_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 8: Multiple NodeMaxRecordsPerLoopIteration attributes (duplicate attributes allowed)
// No error expected - duplicate attributes are accepted
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NodeMaxRecordsPerLoopIteration(20)]  // Duplicate - last one wins
[NumThreads(1,1,1)]
void duplicate_records_per_iteration(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 11: Loop attributes with wrong argument types (string instead of uint)
// expected-error@+5{{'NodeMaxLoopIterations' attribute requires an integer constant}}
// expected-error@+4{{NodeMaxLoopIterations value must be greater than 0}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations("100")]  // Wrong type - string not allowed
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void wrong_type_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 12: Loop attributes with floating point values (gets value 100, then reports 0 error)
// expected-warning@+5{{attribute 'NodeMaxLoopIterations' must have a uint literal argument}}
// expected-error@+4{{NodeMaxLoopIterations value must be greater than 0}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100.5)]  // Float instead of uint
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void float_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 13: Empty NodeMaxLoopIterations
// expected-error@+4{{'NodeMaxLoopIterations' attribute takes one argument}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations()]  // No argument
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void empty_iterations_arg(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 14: Too many arguments to NodeMaxLoopIterations
// expected-error@+4{{'NodeMaxLoopIterations' attribute takes one argument}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100, 200)]  // Too many arguments
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void too_many_iterations_args(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 15: Empty NodeMaxRecordsPerLoopIteration
// expected-error@+6{{'NodeMaxRecordsPerLoopIteration' attribute takes one argument}}
// expected-error@+4{{NodeMaxLoopIterations requires NodeMaxRecordsPerLoopIteration to also be specified}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration()]  // No argument
[NumThreads(1,1,1)]
void empty_records_arg(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 16: Very large value that causes overflow
// expected-error@+4{{NodeMaxLoopIterations value 3567587327 exceeds maximum of 16777214}}
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(999999999999)]  // Overflow
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void overflow_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self) {}

// Test 17: Loop attributes on library entry (not specific shader)
// expected-error@+1{{attribute 'NodeMaxLoopIterations' only applies to node shader stage}}
[NodeMaxLoopIterations(100)]
// expected-error@+1{{attribute 'NodeMaxRecordsPerLoopIteration' only applies to node shader stage}}
[NodeMaxRecordsPerLoopIteration(10)]
void library_function() {}

// Test 18: GetCurrentLoopIterationIndex with arguments (should have none)
// expected-error@+5{{use of undeclared identifier 'GetCurrentLoopIterationIndex'}}
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void iter_index_with_args(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex(5);  // Wrong
}

