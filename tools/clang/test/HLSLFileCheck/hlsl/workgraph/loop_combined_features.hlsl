// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Combined features: loops with recursion, shared inputs, mesh nodes, etc.

struct RECORD {
  uint data;
  uint iter;
  uint depth;
};

// Test 1: Loop with recursive node inside
// CHECK-LABEL: define void @loop_with_recursion_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(25)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void loop_with_recursion_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> recursiveNode)
{
    uint loopIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    ThreadNodeOutputRecords<RECORD> rec = recursiveNode.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().iter = loopIter;
    rec.Get().depth = 0;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @recursive_node_in_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxRecursionDepth(10)]
[NumThreads(1,1,1)]
void recursive_node_in_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self,
    [MaxRecords(10)] NodeOutput<RECORD> loopEntry)
{
    uint loopIter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    uint recursionDepth = GetRemainingRecursionLevels();
    
    RECORD data = input.Get();
    data.depth++;
    
    if (recursionDepth > 0) {
        // Continue recursion
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else if (loopIter < 24) {
        // Exit recursion, continue loop
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    }
    // Otherwise, exit both recursion and loop
}

// Test 2: Loop with shared input nodes
// CHECK-LABEL: define void @shared_input_loop_a
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(30)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void shared_input_loop_a(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> sharedProcessor)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = sharedProcessor.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.Get().iter = iter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @shared_input_loop_b
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(40)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void shared_input_loop_b(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> sharedProcessor)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = sharedProcessor.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 2;
    rec.Get().iter = iter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @shared_processor_node
[Shader("node")]
[NodeLaunch("thread")]
[NodeShareInputOf("shared_input_loop_a")]  // Shares input with loop_a
[NumThreads(1,1,1)]
void shared_processor_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> loopA,
    [MaxRecords(8)] NodeOutput<RECORD> loopB)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets iteration from whichever loop called it
    
    RECORD data = input.Get();
    
    // Feedback to appropriate loop based on stored iteration
    if (data.iter < 29) {
        ThreadNodeOutputRecords<RECORD> rec = loopA.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else if (data.iter < 39) {
        ThreadNodeOutputRecords<RECORD> rec = loopB.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    }
}

// Test 3: Loop calling mesh node (mesh node not in loop)
// CHECK-LABEL: define void @loop_to_mesh_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(20)]
[NodeMaxRecordsPerLoopIteration(6)]
[NumThreads(1,1,1)]
void loop_to_mesh_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(3)] NodeOutput<RECORD> self,
    [MaxRecords(3)] NodeOutput<RECORD> meshNode)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    if (iter < 19) {
        // Continue loop
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    } else {
        // Exit to mesh node
        ThreadNodeOutputRecords<RECORD> rec = meshNode.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

#if 0 // TODO: Add test for mesh output node
// TODO-CHECK-LABEL: define void @mesh_output_node
[Shader("node")]
[NodeLaunch("mesh")]
[NodeMaxDispatchGrid(32, 32, 1)]
[NumThreads(128,1,1)]
[OutputTopology("triangle")]
void mesh_output_node(
    DispatchNodeInputRecord<RECORD> input,
    out indices uint3 triangles[128],
    out vertices float3 verts[64])
{
    uint iter = GetCurrentLoopIterationIndex();  // Should return 0 - mesh not in loop
    // TODO-CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Generate mesh
    SetMeshOutputCounts(64, 128);
}
#endif

// Test 4: Loop with MaxRecordsSharedWith
// CHECK-LABEL: define void @shared_budget_loop
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(35)]
[NodeMaxRecordsPerLoopIteration(16)]
[NumThreads(64,1,1)]
void shared_budget_loop(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> self,
    [MaxRecordsSharedWith(self)] NodeOutput<RECORD> alternate)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    if (iter < 34) {
        // Feedback through different paths, sharing budget
        if (input.Get().data % 2 == 0) {
            ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
            rec.Get() = input.Get();
            rec.OutputComplete();
        } else {
            ThreadNodeOutputRecords<RECORD> rec = alternate.GetThreadNodeOutputRecords(1);
            rec.Get() = input.Get();
            rec.OutputComplete();
        }
    }
}

// CHECK-LABEL: define void @alternate_path_node
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void alternate_path_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> loopEntry)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    
    ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.OutputComplete();
}

RWByteAddressBuffer rwbuffer : register(u0);

// Test 5: Loop with EmptyNodeInput/Output
// CHECK-LABEL: define void @empty_loop_entry
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(64)]
[NumThreads(256,1,1)]
void empty_loop_entry(
    EmptyNodeInput input,
    [MaxRecords(64)] EmptyNodeOutput self)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Increment counter for each iteration
    uint original;
    rwbuffer.InterlockedAdd(0, 1, original);
    
    if (iter < 49) {
        // Continue loop
        self.GroupIncrementOutputCount(1);
    }
}

// Test 6: Loop with node array outputs
// CHECK-LABEL: define void @loop_array_outputs
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(30)]
[NodeMaxRecordsPerLoopIteration(32)]
[NumThreads(1,1,1)]
void loop_array_outputs(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(32)][MaxRecordsPerNode(1)][NodeArraySize(8)] NodeOutputArray<RECORD> processors,
    [MaxRecords(8)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Dispatch to multiple processors
    for (uint i = 0; i < 4; i++) {
        ThreadNodeOutputRecords<RECORD> rec = processors[i].GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data + i;
        rec.Get().iter = iter;
        rec.OutputComplete();
    }
    
    // One processor feeds back to loop
}

// CHECK-LABEL: define void @array_processor_feedback
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_processor_feedback(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> loopEntry)
{
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration
    
    if (iter < 29) {
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get() = input.Get();
        rec.OutputComplete();
    }
}

// CHECK-LABEL: define void @array_processor_no_feedback_1
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_processor_no_feedback_1(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration (part of loop)
}

// CHECK-LABEL: define void @array_processor_no_feedback_2
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_processor_no_feedback_2(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration (part of loop)
}

// CHECK-LABEL: define void @array_processor_no_feedback_3
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void array_processor_no_feedback_3(ThreadNodeInputRecord<RECORD> input) {
    uint iter = GetCurrentLoopIterationIndex();  // Gets loop iteration (part of loop)
}

// Test 7: Nested loops with different recursion depths
// CHECK-LABEL: define void @nested_loop_recursion_outer
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(15)]
[NodeMaxRecordsPerLoopIteration(5)]
[NumThreads(1,1,1)]
void nested_loop_recursion_outer(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> innerLoop)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().iter = outerIter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @nested_loop_recursion_inner
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(12)]
[NodeMaxRecordsPerLoopIteration(4)]
[NumThreads(1,1,1)]
void nested_loop_recursion_inner(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(4)] NodeOutput<RECORD> recursiveNode)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = recursiveNode.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().depth = 0;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @nested_recursive_node
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxRecursionDepth(8)]
[NumThreads(1,1,1)]
void nested_recursive_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(4)] NodeOutput<RECORD> self,
    [MaxRecords(4)] NodeOutput<RECORD> innerLoop,
    [MaxRecords(5)] NodeOutput<RECORD> outerLoop)
{
    uint loopIter = GetCurrentLoopIterationIndex();  // Gets inner loop iteration
    uint recursionLevels = GetRemainingRecursionLevels();
    
    RECORD data = input.Get();
    data.depth++;
    
    if (recursionLevels > 0) {
        // Continue recursion
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else if (loopIter < 11) {
        // Exit recursion, continue inner loop
        ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else if (data.iter < 14) {
        // Exit inner loop, continue outer loop
        ThreadNodeOutputRecords<RECORD> rec = outerLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    }
}

struct CONSTANT_BUFFER_DATA {
    float4 data[4];
};
ConstantBuffer<CONSTANT_BUFFER_DATA> constantBuffer : register(b0);

// Test 8: Loop with local root arguments
// CHECK-LABEL: define void @loop_with_local_root
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(40)]
[NodeMaxRecordsPerLoopIteration(10)]
[NodeLocalRootArgumentsTableIndex(0)]
[NumThreads(1,1,1)]
void loop_with_local_root(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    
    // Use local root arguments
    float factor = constantBuffer.data[iter % 4].x;
    
    if (iter < 39) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().data = (uint)(input.Get().data * factor);
        rec.OutputComplete();
    }
}

// Test 9: Complex: nested loops + recursion + shared input + arrays
// CHECK-LABEL: define void @complex_combo_entry
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(16, 16, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(20)]
[NodeMaxRecordsPerLoopIteration(32)]
[NumThreads(128,1,1)]
void complex_combo_entry(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(32)][MaxRecordsPerNode(1)][NodeArraySize(4)] NodeOutputArray<RECORD> innerLoops)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    
    // Distribute to inner loops based on data
    uint index = input.Get().data % 4;
    ThreadNodeOutputRecords<RECORD> rec = innerLoops[index].GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().iter = outerIter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @complex_inner_loop
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(15)]
[NodeMaxRecordsPerLoopIteration(8)]
[NumThreads(1,1,1)]
void complex_inner_loop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> recursiveSharedNode)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    
    ThreadNodeOutputRecords<RECORD> rec = recursiveSharedNode.GetThreadNodeOutputRecords(1);
    rec.Get() = input.Get();
    rec.Get().depth = 0;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @complex_recursive_shared
[Shader("node")]
[NodeLaunch("thread")]
[NodeShareInputOf("complex_inner_loop")]
[NodeMaxRecursionDepth(6)]
[NumThreads(1,1,1)]
void complex_recursive_shared(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)] NodeOutput<RECORD> self,
    [MaxRecords(8)] NodeOutput<RECORD> innerLoop,
    [MaxRecords(32)] NodeOutput<RECORD> outerLoop)
{
    uint loopIter = GetCurrentLoopIterationIndex();  // Inner loop iteration
    uint recursionLevels = GetRemainingRecursionLevels();
    
    RECORD data = input.Get();
    data.depth++;
    
    if (recursionLevels > 0) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else if (loopIter < 14) {
        ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    } else if (data.iter < 19) {
        ThreadNodeOutputRecords<RECORD> rec = outerLoop.GetThreadNodeOutputRecords(1);
        rec.Get() = data;
        rec.OutputComplete();
    }
}

// Verify all intrinsics
// CHECK-DAG: declare i32 @dx.op.getCurrentLoopIterationIndex(i32)
// CHECK-DAG: declare i32 @dx.op.getRemainingRecursionLevels(i32)

