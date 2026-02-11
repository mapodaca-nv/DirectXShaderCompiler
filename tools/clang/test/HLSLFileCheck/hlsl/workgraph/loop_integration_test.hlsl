// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Integration test for Work Graph Loop features
// Tests all components working together: attributes, metadata, and intrinsic

struct RECORD {
  uint value;
  uint iteration;
  uint outerIteration;
};

// ============================================================================
// Test 1: Simple loop with all features
// ============================================================================

// CHECK-LABEL: define void @simple_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void simple_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopNode)
{
    ThreadNodeOutputRecords<RECORD> output = loopNode.GetThreadNodeOutputRecords(1);
    output.Get().value = input.Get().value;
    output.Get().iteration = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    output.OutputComplete();
}

RWByteAddressBuffer rwbuffer : register(u0);

// CHECK-LABEL: define void @simple_loop_node
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NumThreads(64,1,1)]
void simple_loop_node(
    DispatchNodeInputRecord<RECORD> input,
    in uint2 GroupCoord : SV_GroupID,
    [MaxRecords(10)] NodeOutput<RECORD> loopEntry,
    [MaxRecords(10)] NodeOutput<RECORD> leafNode)
{
    uint iteration = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Write result
    uint index = input.Get().value * 100 + iteration;
    rwbuffer.Store(index * 4, input.Get().value);
    
    // Only group (0,0) can loop back
    if ((GroupCoord.x + GroupCoord.y) == 0) {
        if (iteration < 99) {
            // Continue loop
            ThreadNodeOutputRecords<RECORD> output = loopEntry.GetThreadNodeOutputRecords(1);
            output.Get().value = input.Get().value + 1;
            output.OutputComplete();
        }
    } else {
        // Exit to leaf
        ThreadNodeOutputRecords<RECORD> output = leafNode.GetThreadNodeOutputRecords(1);
        output.Get().value = input.Get().value;
        output.Get().iteration = iteration;
        output.OutputComplete();
    }
}

// ============================================================================
// Test 2: Nested loops with all features
// ============================================================================

// CHECK-LABEL: define void @outer_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(5)]
[NumThreads(1,1,1)]
void outer_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> innerLoopEntry)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    ThreadNodeOutputRecords<RECORD> output = innerLoopEntry.GetThreadNodeOutputRecords(1);
    output.Get().value = input.Get().value;
    output.Get().outerIteration = outerIter;
    output.OutputComplete();
}

// CHECK-LABEL: define void @inner_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(20)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void inner_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> innerLoopNode)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    ThreadNodeOutputRecords<RECORD> output = innerLoopNode.GetThreadNodeOutputRecords(1);
    output.Get().value = input.Get().value;
    output.Get().iteration = innerIter;
    output.Get().outerIteration = input.Get().outerIteration;
    output.OutputComplete();
}

// CHECK-LABEL: define void @inner_loop_node
[Shader("node")]
[NodeLaunch("coalescing")]
[NumThreads(1,1,1)]
void inner_loop_node(
    [MaxRecords(8)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> innerLoopEntry,
    [MaxRecords(8)] NodeOutput<RECORD> outerLoopEntry)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    uint count = input.Count();
    for (uint i = 0; i < count; i++) {
        RECORD rec = input.Get(i);
        
        // Write result
        uint index = rec.outerIteration * 1000 + innerIter * 10 + rec.value;
        rwbuffer.Store(index * 4, rec.value);
        
        if (innerIter < 19) {
            // Continue inner loop
            ThreadNodeOutputRecords<RECORD> output = innerLoopEntry.GetThreadNodeOutputRecords(1);
            output.Get() = rec;
            output.Get().value++;
            output.OutputComplete();
        } else if (rec.outerIteration < 9) {
            // Exit inner loop, continue outer loop
            ThreadNodeOutputRecords<RECORD> output = outerLoopEntry.GetThreadNodeOutputRecords(1);
            output.Get().value = rec.value;
            output.OutputComplete();
        }
        // Otherwise, exit both loops (no output)
    }
}

// ============================================================================
// Test 3: Loop with maximum values
// ============================================================================

// CHECK-LABEL: define void @max_values_loop
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(16, 16, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(16777214)] // (2^24)-2
[NodeMaxRecordsPerLoopIteration(256)]
[NumThreads(256,1,1)]
void max_values_loop(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(256)] NodeOutput<RECORD> self)
{
    uint iteration = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Write result
    rwbuffer.Store(iteration * 4, input.Get().value);
    
    // Loop condition
    if (iteration < 16777213) {
        ThreadNodeOutputRecords<RECORD> output = self.GetThreadNodeOutputRecords(1);
        output.Get().value = input.Get().value + 1;
        output.OutputComplete();
    }
}

// ============================================================================
// Test 4: Loop entry targeting itself
// ============================================================================

// CHECK-LABEL: define void @self_targeting_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(1000)]
[NodeMaxRecordsPerLoopIteration(16)]
[NumThreads(1,1,1)]
void self_targeting_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> self)
{
    uint iteration = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Write current state
    rwbuffer.Store(iteration * 8, input.Get().value);
    rwbuffer.Store(iteration * 8 + 4, iteration);
    
    // Continue looping
    if (iteration < 999 && input.Get().value < 1000) {
        ThreadNodeOutputRecords<RECORD> output = self.GetThreadNodeOutputRecords(1);
        output.Get().value = input.Get().value + iteration + 1;
        output.Get().iteration = iteration + 1;
        output.OutputComplete();
    }
}

// Verify all required DXIL declarations are present
// CHECK-DAG: declare i32 @dx.op.getCurrentLoopIterationIndex(i32)

