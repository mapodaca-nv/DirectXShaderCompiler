// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Comprehensive edge case and stress testing for Work Graph Loops

struct RECORD {
  uint data;
  uint iteration;
};

// Test 1: Minimum valid loop values
// CHECK-LABEL: define void @min_loop_values
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(1)]  // Minimum: 1
[NodeMaxRecordsPerLoopIteration(1)]  // Minimum: 1
[NumThreads(1,1,1)]
void min_loop_values(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output)
{
    uint iter = GetCurrentLoopIterationIndex();
}

// Test 2: Maximum valid loop iteration value
// CHECK-LABEL: define void @max_loop_iterations
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(16777214)]  // Maximum: 2^24 - 2
[NodeMaxRecordsPerLoopIteration(1)]
[NumThreads(1,1,1)]
void max_loop_iterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output)
{
    uint iter = GetCurrentLoopIterationIndex();
}

// Test 3: Maximum valid records per iteration
// CHECK-LABEL: define void @max_records_per_iteration
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(256)]  // Maximum: 256
[NumThreads(1,1,1)]
void max_records_per_iteration(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(256)] NodeOutput<RECORD> output)
{
    uint iter = GetCurrentLoopIterationIndex();
}

// Test 4: All maximum values together
// CHECK-LABEL: define void @all_max_values
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(256, 256, 1)]  // Maximum dispatch grid
[NodeIsProgramEntry]
[NodeMaxLoopIterations(16777214)]  // Max iterations
[NodeMaxRecordsPerLoopIteration(256)]  // Max records
[NumThreads(1024,1,1)]  // Max threads
void all_max_values(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(256)] NodeOutput<RECORD> output)
{
    uint iter = GetCurrentLoopIterationIndex();
}

// Test 5: Loop with maximum output array size
// CHECK-LABEL: define void @loop_max_array_size
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(1000)]
[NodeMaxRecordsPerLoopIteration(128)]
[NumThreads(1,1,1)]
void loop_max_array_size(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(128)][MaxRecordsPerNode(1)][NodeArraySize(256)] NodeOutputArray<RECORD> outputs)
{
    // Large output array with loop
    uint index = input.Get().data % 256;
    ThreadNodeOutputRecords<RECORD> rec = outputs[index].GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.OutputComplete();
}

RWByteAddressBuffer rwbuffer : register(u0);

// Test 6: Loop iteration index at various boundaries
// CHECK-LABEL: define void @iteration_boundary_checks
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(1000)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void iteration_boundary_checks(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Test boundaries: 0, 1, max-1, max
    if (iter == 0) {
        // First iteration
        rwbuffer.Store(0, iter);
    } else if (iter == 1) {
        // Second iteration
        rwbuffer.Store(4, iter);
    } else if (iter == 998) {
        // Second to last iteration
        rwbuffer.Store(8, iter);
    } else if (iter == 999) {
        // Last iteration before termination
        rwbuffer.Store(12, iter);
        return;  // Terminate
    }
    
    // Continue loop
    ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.OutputComplete();
}

// Test 7: Multiple loop outputs with maximal configuration
// CHECK-LABEL: define void @multiple_loop_outputs
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(5000)]
[NodeMaxRecordsPerLoopIteration(200)]
[NumThreads(512,1,1)]
void multiple_loop_outputs(
    [MaxRecords(200)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(100)] NodeOutput<RECORD> loopPath1,
    [MaxRecords(100)] NodeOutput<RECORD> loopPath2)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)

    uint count = input.Count();
    for (uint i = 0; i < count; i++) {
        if (iter % 2 == 0) {
            GroupNodeOutputRecords<RECORD> rec = loopPath1.GetGroupNodeOutputRecords(1);
            rec.Get().data = input.Get(i).data;
            rec.OutputComplete();
        } else {
            GroupNodeOutputRecords<RECORD> rec = loopPath2.GetGroupNodeOutputRecords(1);
            rec.Get().data = input.Get(i).data;
            rec.OutputComplete();
        }
    }
}

// Test 8: Loop with conditional output (sparse feedback)
// CHECK-LABEL: define void @sparse_loop_feedback
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(64, 64, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(64)]  // One thread per dispatch can feedback
[NumThreads(256,1,1)]
void sparse_loop_feedback(
    DispatchNodeInputRecord<RECORD> input,
    in uint3 GroupID : SV_GroupID,
    in uint3 GroupThreadID : SV_GroupThreadID,
    [MaxRecords(64)] NodeOutput<RECORD> self)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Only specific threads provide feedback
    if (GroupThreadID.x == 0 && GroupThreadID.y == 0 && GroupThreadID.z == 0) {
        if (iter < 99) {
            GroupNodeOutputRecords<RECORD> rec = self.GetGroupNodeOutputRecords(1);
            rec.Get().data = input.Get().data + 1;
            rec.OutputComplete();
        }
    }
}

// Test 9: Empty node output within loop
// CHECK-LABEL: define void @empty_output_in_loop
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(32)]
[NumThreads(128,1,1)]
void empty_output_in_loop(
    EmptyNodeInput input,
    [MaxRecords(32)] EmptyNodeOutput loopOutput)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // EmptyNodeOutput with loop
    if (iter < 49) {
        loopOutput.GroupIncrementOutputCount(1);
    }
}



// Verify all opcodes generated (no overload suffix; NumOverloadDims=0)
// CHECK-DAG: declare i32 @dx.op.getCurrentLoopIterationIndex(i32)

