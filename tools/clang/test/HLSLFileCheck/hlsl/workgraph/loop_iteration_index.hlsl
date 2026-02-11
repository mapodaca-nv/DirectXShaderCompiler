// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Tests for GetCurrentLoopIterationIndex() intrinsic

struct RECORD
{
    uint value;
    uint iteration;
};

// Test 1: GetCurrentLoopIterationIndex in loop entry node
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(1)]
void LoopEntry_UseIterationIndex(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
    uint iteration = GetCurrentLoopIterationIndex();
    
    // Use iteration index for conditional logic
    if (iteration < 50) {
        // Early iterations
        ThreadNodeOutputRecords<RECORD> outRec = output.GetThreadNodeOutputRecords(1);
        outRec.Get().value = iteration * 2;
        outRec.Get().iteration = iteration;
        outRec.OutputComplete();
    }
}

// CHECK: define void @LoopEntry_UseIterationIndex()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

// Test 2: GetCurrentLoopIterationIndex in inner loop node
[Shader("node")]
[NodeLaunch("thread")]
void InnerNode_UseIterationIndex(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> loopEntry,
    [MaxRecords(1)] NodeOutput<RECORD> exitNode
)
{
    uint currentIter = GetCurrentLoopIterationIndex();
    
    // Loop back or exit based on iteration
    if (currentIter < 99) {
        // Continue loop
        ThreadNodeOutputRecords<RECORD> outRec = loopEntry.GetThreadNodeOutputRecords(1);
        outRec.Get().iteration = currentIter + 1;
        outRec.OutputComplete();
    } else {
        // Exit loop
        ThreadNodeOutputRecords<RECORD> outRec = exitNode.GetThreadNodeOutputRecords(1);
        outRec.Get().iteration = currentIter;
        outRec.OutputComplete();
    }
}

// CHECK: define void @InnerNode_UseIterationIndex()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

// Test 3: GetCurrentLoopIterationIndex in broadcasting node
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NumThreads(64, 1, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(64)]
void BroadcastLoop_UseIterationIndex(
    DispatchNodeInputRecord<RECORD> input,
    in uint2 GroupID : SV_GroupID,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
    uint iteration = GetCurrentLoopIterationIndex();
    
    // Only group (0,0) continues the loop
    if (GroupID.x == 0 && GroupID.y == 0) {
        if (iteration < 49) {
            ThreadNodeOutputRecords<RECORD> outRec = output.GetThreadNodeOutputRecords(1);
            outRec.Get().iteration = iteration;
            outRec.OutputComplete();
        }
    }
}

// CHECK: define void @BroadcastLoop_UseIterationIndex()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

// Test 4: GetCurrentLoopIterationIndex outside of loop (should return 0)
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
void NonLoopNode_UseIterationIndex(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
    // Should return 0 since not in a loop
    uint iteration = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> outRec = output.GetThreadNodeOutputRecords(1);
    outRec.Get().iteration = iteration;  // Will be 0
    outRec.OutputComplete();
}

// CHECK: define void @NonLoopNode_UseIterationIndex()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

// Test 5: Multiple calls to GetCurrentLoopIterationIndex
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(2)]
void LoopEntry_MultipleIterationCalls(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(2)] NodeOutput<RECORD> output
)
{
    uint iter1 = GetCurrentLoopIterationIndex();
    uint iter2 = GetCurrentLoopIterationIndex();
    
    // Both should return the same value
    ThreadNodeOutputRecords<RECORD> outRec = output.GetThreadNodeOutputRecords(2);
    outRec.Get(0).iteration = iter1;
    outRec.Get(1).iteration = iter2;
    outRec.OutputComplete();
}

// CHECK: define void @LoopEntry_MultipleIterationCalls()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

// Test 6: Nested loop example (inner loop gets its own index)
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(1)]
void OuterLoopEntry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> innerLoop
)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> outRec = innerLoop.GetThreadNodeOutputRecords(1);
    outRec.Get().value = outerIter;
    outRec.OutputComplete();
}

// CHECK: define void @OuterLoopEntry()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(5)]
[NodeMaxRecordsPerLoopIteration(1)]
void InnerLoopEntry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> innerNode,
    [MaxRecords(1)] NodeOutput<RECORD> outerLoop
)
{
    // This will return the inner loop's iteration index
    uint innerIter = GetCurrentLoopIterationIndex();
    
    if (innerIter < 4) {
        // Continue inner loop
        ThreadNodeOutputRecords<RECORD> outRec = innerNode.GetThreadNodeOutputRecords(1);
        outRec.OutputComplete();
    } else {
        // Exit to outer loop
        ThreadNodeOutputRecords<RECORD> outRec = outerLoop.GetThreadNodeOutputRecords(1);
        outRec.OutputComplete();
    }
}

// CHECK: define void @InnerLoopEntry()
// CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

