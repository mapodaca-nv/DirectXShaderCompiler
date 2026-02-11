// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Tests for [NodeMaxLoopIterations] and [NodeMaxRecordsPerLoopIteration] attributes

struct RECORD
{
    uint value;
};

// Test 1: Basic loop entry node with valid attributes
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(4)]
void LoopEntryNode_Valid(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// CHECK: define void @LoopEntryNode_Valid()
// CHECK: ret void

// Test 2: Loop entry node with maximum iteration count
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(16777214)]  // (2^24)-2
[NodeMaxRecordsPerLoopIteration(1)]
void LoopEntryNode_MaxIterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// CHECK: define void @LoopEntryNode_MaxIterations()

// Test 3: Loop entry node with maximum records per iteration
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(256)]  // Maximum value
void LoopEntryNode_MaxRecords(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// CHECK: define void @LoopEntryNode_MaxRecords()

// Test 4: Broadcasting loop entry node
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NumThreads(64, 1, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(128)]
void LoopEntryNode_Broadcasting(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// CHECK: define void @LoopEntryNode_Broadcasting()

// Test 5: Coalescing loop entry node
[Shader("node")]
[NodeLaunch("coalescing")]
[NumThreads(128, 1, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(25)]
[NodeMaxRecordsPerLoopIteration(64)]
void LoopEntryNode_Coalescing(
    [MaxRecords(256)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// CHECK: define void @LoopEntryNode_Coalescing()

// Test 6: Node within loop (no loop attributes)
[Shader("node")]
[NodeLaunch("thread")]
void InnerLoopNode(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> loopEntry
)
{
}

// CHECK: define void @InnerLoopNode()

