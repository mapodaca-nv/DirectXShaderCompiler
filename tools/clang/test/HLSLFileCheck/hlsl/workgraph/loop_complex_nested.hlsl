// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Complex nested loop scenarios and topology tests

struct RECORD {
  uint data;
  uint outerIter;
  uint middleIter;
  uint innerIter;
  uint level;
};

// Test 1: Triple-nested loops
// CHECK-LABEL: define void @outer_loop_l1
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(5)]
[NumThreads(1,1,1)]
void outer_loop_l1(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> middleLoop)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    ThreadNodeOutputRecords<RECORD> rec = middleLoop.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.Get().outerIter = outerIter;
    rec.Get().level = 1;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @middle_loop_l2
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(8)]
[NodeMaxRecordsPerLoopIteration(4)]
[NumThreads(1,1,1)]
void middle_loop_l2(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(4)] NodeOutput<RECORD> innerLoop)
{
    uint middleIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.Get().outerIter = input.Get().outerIter;
    rec.Get().middleIter = middleIter;
    rec.Get().level = 2;
    rec.OutputComplete();
}

RWByteAddressBuffer rwbuffer : register(u0);

// CHECK-LABEL: define void @inner_loop_l3
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(6)]
[NodeMaxRecordsPerLoopIteration(3)]
[NumThreads(1,1,1)]
void inner_loop_l3(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(3)] NodeOutput<RECORD> self,
    [MaxRecords(3)] NodeOutput<RECORD> middleLoop,
    [MaxRecords(3)] NodeOutput<RECORD> outerLoop)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    RECORD inRec = input.Get();
    uint index = (inRec.outerIter * 100) + (inRec.middleIter * 10) + innerIter;
    rwbuffer.Store(index * 4, inRec.data);
    
    if (innerIter < 5) {
        // Continue inner loop
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = inRec;
        rec.Get().innerIter = innerIter;
        rec.OutputComplete();
    } else if (inRec.middleIter < 7) {
        // Exit inner, continue middle
        ThreadNodeOutputRecords<RECORD> rec = middleLoop.GetThreadNodeOutputRecords(1);
        rec.Get().data = inRec.data;
        rec.Get().outerIter = inRec.outerIter;
        rec.OutputComplete();
    } else if (inRec.outerIter < 9) {
        // Exit middle, continue outer
        ThreadNodeOutputRecords<RECORD> rec = outerLoop.GetThreadNodeOutputRecords(1);
        rec.Get().data = inRec.data;
        rec.OutputComplete();
    }
    // Otherwise, exit all loops
}

// Test 2: Sibling loops (parallel loops, not nested)
// CHECK-LABEL: define void @parent_dispatcher
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void parent_dispatcher(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopA,
    [MaxRecords(10)] NodeOutput<RECORD> loopB)
{
    // Dispatch to both sibling loops
    if (input.Get().data % 2 == 0) {
        ThreadNodeOutputRecords<RECORD> rec = loopA.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else {
        ThreadNodeOutputRecords<RECORD> rec = loopB.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @sibling_loop_a
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void sibling_loop_a(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    // Independent from sibling_loop_b's iterations
    
    if (iter < 49) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data + iter;
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @sibling_loop_b
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(75)]
[NodeMaxRecordsPerLoopIteration(6)]
[NumThreads(1,1,1)]
void sibling_loop_b(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(6)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    // Independent from sibling_loop_a's iterations
    
    if (iter < 74) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data * iter;
        rec.OutputComplete();
    }
}

// Test 3: Diamond-shaped nested loops
// CHECK-LABEL: define void @diamond_top
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(20)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void diamond_top(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> leftBranch,
    [MaxRecords(5)] NodeOutput<RECORD> rightBranch)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Split to two branches
    if (input.Get().data % 2 == 0) {
        ThreadNodeOutputRecords<RECORD> rec = leftBranch.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else {
        ThreadNodeOutputRecords<RECORD> rec = rightBranch.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @diamond_left
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void diamond_left(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> diamondBottom)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets outer loop iteration
    
    ThreadNodeOutputRecords<RECORD> rec = diamondBottom.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 2;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @diamond_right
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void diamond_right(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> diamondBottom)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets outer loop iteration
    
    ThreadNodeOutputRecords<RECORD> rec = diamondBottom.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 3;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @diamond_bottom
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void diamond_bottom(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> diamondTop)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets outer loop iteration
    
    if (iter < 19) {
        // Feedback to top of diamond
        ThreadNodeOutputRecords<RECORD> rec = diamondTop.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// Test 4: Loop with fan-out and fan-in
// CHECK-LABEL: define void @fanout_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(30)]
[NodeMaxRecordsPerLoopIteration(16)]
[NumThreads(1,1,1)]
void fanout_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(16)][MaxRecordsPerNode(1)][NodeArraySize(4)] NodeOutputArray<RECORD> processors)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Fan out to 4 processors
    for (uint i = 0; i < 4; i++) {
        ThreadNodeOutputRecords<RECORD> rec = processors[i].GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data + i;
        rec.Get().outerIter = iter;
        rec.Get().level = i;
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @processor_node
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(4, 4, 1)]
[NumThreads(64,1,1)]
void processor_node(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> collector)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop entry iteration
    
    // Process and send to collector
    ThreadNodeOutputRecords<RECORD> rec = collector.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 2;
    rec.Get().outerIter = input.Get().outerIter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @collector_node
[Shader("node")]
[NodeLaunch("coalescing")]
[NumThreads(128,1,1)]
void collector_node(
    [MaxRecords(64)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> loopEntry)
{
    uint iter = GetCurrentLoopIterationIndex();
    uint count = input.Count();
    
    // Collect and feedback to loop entry
    uint sum = 0;
    for (uint i = 0; i < count; i++) {
        sum += input.Get(i).data;
    }
    
    if (input.Get(0).outerIter < 29) {
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get().data = sum;
        rec.OutputComplete();
    }
}

// Test 5: Nested loops with different launch types at each level
// CHECK-LABEL: define void @mixed_launch_outer
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(15)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void mixed_launch_outer(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> middleLoop)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = middleLoop.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().outerIter = iter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @mixed_launch_middle
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NodeMaxLoopIterations(12)]
[NodeMaxRecordsPerLoopIteration(32)]
[NumThreads(128,1,1)]
void mixed_launch_middle(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(32)] NodeOutput<RECORD> innerLoop)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().middleIter = iter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @mixed_launch_inner
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(64)]
[NumThreads(256,1,1)]
void mixed_launch_inner(
    [MaxRecords(64)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(32)] NodeOutput<RECORD> self,
    [MaxRecords(32)] NodeOutput<RECORD> middleLoop,
    [MaxRecords(8)] NodeOutput<RECORD> outerLoop)
{
    uint iter = GetCurrentLoopIterationIndex();
    uint count = input.Count();
    
    RECORD firstRec = input.Get(0);
    
    if (iter < 9) {
        // Continue inner loop
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = firstRec;
        rec.OutputComplete();
    } else if (firstRec.middleIter < 11) {
        // Exit inner, continue middle
        ThreadNodeOutputRecords<RECORD> rec = middleLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = firstRec;
        rec.OutputComplete();
    } else if (firstRec.outerIter < 14) {
        // Exit middle, continue outer
        ThreadNodeOutputRecords<RECORD> rec = outerLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = firstRec;
        rec.OutputComplete();
    }
}

// Test 6: Asymmetric nested loops (different iteration counts)
// CHECK-LABEL: define void @asym_outer
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(3)]
[NodeMaxRecordsPerLoopIteration(2)]
[NumThreads(1,1,1)]
void asym_outer(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(2)] NodeOutput<RECORD> innerLoop)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
    rec.Get().outerIter = outerIter;
    rec.Get().data = input.Get().data;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @asym_inner
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(100)]  // Much larger than outer
[NodeMaxRecordsPerLoopIteration(2)]
[NumThreads(1,1,1)]
void asym_inner(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(2)] NodeOutput<RECORD> self,
    [MaxRecords(2)] NodeOutput<RECORD> outerLoop)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    
    // Record iterations
    uint index = (input.Get().outerIter * 1000) + innerIter;
    rwbuffer.Store(index * 4, input.Get().data);
    
    if (innerIter < 99) {
        // Continue inner loop many times
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else if (input.Get().outerIter < 2) {
        // Exit inner, continue outer (only 3 times)
        ThreadNodeOutputRecords<RECORD> rec = outerLoop.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data + innerIter;
        rec.OutputComplete();
    }
}

// Verify intrinsic declarations
// CHECK-DAG: declare i32 @dx.op.getCurrentLoopIterationIndex(i32)

