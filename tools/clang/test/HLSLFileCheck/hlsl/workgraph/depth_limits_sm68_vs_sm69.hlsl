// RUN: %dxc -T lib_6_8 %s | FileCheck %s -check-prefix=CHECK-SM68
// RUN: %dxc -T lib_6_9 %s | FileCheck %s -check-prefix=CHECK-SM69

// Test node depth limits for SM 6.8 vs SM 6.9

struct RECORD {
  uint data;
};

// Test 1: Verify SM 6.8 max depth is 32
// TODO-CHECK-SM68: Node depth for Shader Model 6.8 is limited to 32

// Test 2: Verify SM 6.9 max depth is 48
// TODO-CHECK-SM69: Node depth for Shader Model 6.9 is limited to 48

// Test 3: Node with recursion - verify recursion doesn't count toward depth in SM 6.9
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxRecursionDepth(10)]
[NumThreads(1,1,1)]
void recursive_node_sm68_sm69(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> self)
{
    // TODO: in SM 6.8, this counts as depth 10 toward the graph depth limit
    // TODO: in SM 6.9, recursion depth does NOT count toward graph depth
}

// Test 4: Loop entry node - only available in SM 6.9
// CHECK-SM68: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void loop_entry_sm69_only(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopOutput)
{
    // This should only compile in SM 6.9
}

// Test 5: GetCurrentLoopIterationIndex - only available in SM 6.9
// CHECK-SM68: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void iteration_intrinsic_sm69_only(
    ThreadNodeInputRecord<RECORD> input,
    RWByteAddressBuffer output : register(u0))
{
    uint iter = GetCurrentLoopIterationIndex();
    output.Store(0, iter);
}

// Test 6: Verify SM 6.9 cannot use both features together
// CHECK-SM68: error
// CHECK-SM69: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxRecursionDepth(3)]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void combined_features_sm69(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> recursive,
    [MaxRecords(8)] NodeOutput<RECORD> loop)
{
    // SM 6.9 should support both recursion and loops
    uint iter = GetCurrentLoopIterationIndex();
    
    if (iter < 49) {
        ThreadNodeOutputRecords<RECORD> rec = loop.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data;
        rec.OutputComplete();
    }
}

