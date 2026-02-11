// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Graph topology and path validation tests

struct RECORD { uint data; uint iter; };

RWByteAddressBuffer results : register(u0);

// Test 1: Loop with multiple entry points from outside
// CHECK-LABEL: define void @external_entry_1
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void external_entry_1(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopEntry)
{
    ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @external_entry_2
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void external_entry_2(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopEntry)
{
    ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 2;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @shared_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(20)]
[NumThreads(1,1,1)]
void shared_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(20)] NodeOutput<RECORD> self,
    [MaxRecords(20)] NodeOutput<RECORD> exitNode)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    if (iter < 49) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else {
        ThreadNodeOutputRecords<RECORD> rec = exitNode.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @shared_exit_node
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void shared_exit_node(
    ThreadNodeInputRecord<RECORD> input)
{
    // Not in loop - should return 0
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    results.Store(0, iter);  // Should be 0
}

// Test 2: Loop with multiple exit paths
// CHECK-LABEL: define void @multi_exit_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(40)]
[NodeMaxRecordsPerLoopIteration(15)]
[NumThreads(1,1,1)]
void multi_exit_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> self,
    [MaxRecords(5)] NodeOutput<RECORD> exitPath1,
    [MaxRecords(5)] NodeOutput<RECORD> exitPath2,
    [MaxRecords(5)] NodeOutput<RECORD> exitPath3)
{
    uint iter = GetCurrentLoopIterationIndex();
    RECORD data = input.Get();
    
    if (iter < 39) {
        // Continue loop
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else {
        // Exit through different paths based on data
        if (data.data % 3 == 0) {
            ThreadNodeOutputRecords<RECORD> rec = exitPath1.GetThreadNodeOutputRecords(1);
            rec.Get() = data;
            rec.OutputComplete();
        } else if (data.data % 3 == 1) {
            ThreadNodeOutputRecords<RECORD> rec = exitPath2.GetThreadNodeOutputRecords(1);
            rec.Get() = data;
            rec.OutputComplete();
        } else {
            ThreadNodeOutputRecords<RECORD> rec = exitPath3.GetThreadNodeOutputRecords(1);
            rec.Get() = data;
            rec.OutputComplete();
        }
    }
}

// CHECK-LABEL: define void @exit_path_1
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void exit_path_1(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// CHECK-LABEL: define void @exit_path_2
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void exit_path_2(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// CHECK-LABEL: define void @exit_path_3
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void exit_path_3(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// Test 3: Complex path through loop (some nodes in loop, some not)
// CHECK-LABEL: define void @complex_path_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(25)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void complex_path_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> branchA,
    [MaxRecords(5)] NodeOutput<RECORD> branchB)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Split to two branches
    if (input.Get().data % 2 == 0) {
        ThreadNodeOutputRecords<RECORD> rec = branchA.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.Get().iter = iter;
        rec.OutputComplete();
    } else {
        ThreadNodeOutputRecords<RECORD> rec = branchB.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.Get().iter = iter;
        rec.OutputComplete();
    }
}

// Branch A feeds back to loop entry - part of loop
// CHECK-LABEL: define void @branch_a_in_loop
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void branch_a_in_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopEntry,
    [MaxRecords(10)] NodeOutput<RECORD> outsideLoop)
{
    uint iter = GetCurrentLoopIterationIndex();  // Returns loop entry iteration
    
    if (iter < 24) {
        // Feedback to loop entry
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else {
        // Exit loop
        ThreadNodeOutputRecords<RECORD> rec = outsideLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// Branch B does NOT feed back - not part of loop
// CHECK-LABEL: define void @branch_b_outside_loop
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void branch_b_outside_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> outsideLoop)
{
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0 - not in loop
    
    ThreadNodeOutputRecords<RECORD> rec = outsideLoop.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().iter = iter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @outside_loop_node
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void outside_loop_node(
    ThreadNodeInputRecord<RECORD> input)
{
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
    results.Store(0, iter);
    results.Store(4, input.Get().iter);
}

// Test 4: Loop with intermediate processing nodes (no feedback from them)
// CHECK-LABEL: define void @loop_with_side_nodes_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(35)]
[NodeMaxRecordsPerLoopIteration(12)]
[NumThreads(1,1,1)]
void loop_with_side_nodes_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(6)] NodeOutput<RECORD> processor,
    [MaxRecords(6)] NodeOutput<RECORD> sideChannel)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Send to processor (in loop)
    ThreadNodeOutputRecords<RECORD> rec1 = processor.GetThreadNodeOutputRecords(1);
    rec1.Get() = input.Get();
    rec1.Get().iter = iter;
    rec1.OutputComplete();
    
    // Also send to side channel (not in loop, no feedback)
    ThreadNodeOutputRecords<RECORD> rec2 = sideChannel.GetThreadNodeOutputRecords(1);
    rec2.Get() = input.Get();
    rec2.Get().iter = iter;
    rec2.OutputComplete();
}

// CHECK-LABEL: define void @processor_in_loop
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void processor_in_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(12)] NodeOutput<RECORD> loopEntry)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    
    if (iter < 34) {
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data * 2;
        rec.Get().iter = iter;
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @side_channel_outside
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void side_channel_outside(
    ThreadNodeInputRecord<RECORD> input)
{
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0 - not in loop
    
    // Log data from each loop iteration
    uint storedIter = input.Get().iter;
    results.Store(storedIter * 8, input.Get().data);
    results.Store(storedIter * 8 + 4, iter);  // Should always be 0
}

// Test 5: Self-targeting loop (simplest case)
// CHECK-LABEL: define void @self_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(1)]
[NumThreads(1,1,1)]
void self_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    results.Store(iter * 4, input.Get().data);
    
    if (iter < 99) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data + 1;
        rec.OutputComplete();
    }
}

// Test 6: Loop entry in array with non-loop nodes
// CHECK-LABEL: define void @array_with_mixed_nodes
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void array_with_mixed_nodes(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(20)][MaxRecordsPerNode(1)][NodeArraySize(4)] NodeOutputArray<RECORD> nodeArray)
{
    // Index 0 is a loop entry node, others are not
    uint index = input.Get().data % 4;
    ThreadNodeOutputRecords<RECORD> rec = nodeArray[index].GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.OutputComplete();
}

// CHECK-LABEL: define void @array_node_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(30)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void array_node_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    if (iter < 29) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @array_node_regular_1
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_node_regular_1(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// CHECK-LABEL: define void @array_node_regular_2
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_node_regular_2(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// CHECK-LABEL: define void @array_node_regular_3
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_node_regular_3(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// Test 7: Deep chain within loop
// CHECK-LABEL: define void @deep_chain_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(20)]
[NodeMaxRecordsPerLoopIteration(5)]
[NumThreads(1,1,1)]
void deep_chain_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> chainNode1)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = chainNode1.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().iter = iter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @chain_node_1
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void chain_node_1(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> chainNode2)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    
    ThreadNodeOutputRecords<RECORD> rec = chainNode2.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.OutputComplete();
}

// CHECK-LABEL: define void @chain_node_2
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void chain_node_2(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> chainNode3)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    
    ThreadNodeOutputRecords<RECORD> rec = chainNode3.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.OutputComplete();
}

// CHECK-LABEL: define void @chain_node_3
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void chain_node_3(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> loopEntry,
    [MaxRecords(5)] NodeOutput<RECORD> exitNode)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    
    if (iter < 19) {
        // Feedback to loop
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else {
        // Exit loop
        ThreadNodeOutputRecords<RECORD> rec = exitNode.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @chain_exit_node
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void chain_exit_node(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0
}

// Verify intrinsic declarations
// CHECK-DAG: declare i32 @dx.op.getCurrentLoopIterationIndex(i32)

