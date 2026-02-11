// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Test DXIL opcode generation for GetCurrentLoopIterationIndex() intrinsic

struct RECORD {
  uint data;
  uint iteration;
};

RWByteAddressBuffer rwbuffer : register(u0);

// Test 1: GetCurrentLoopIterationIndex in loop entry node
// CHECK-LABEL: define void @loop_with_iteration_index
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void loop_with_iteration_index(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopOutput)
{
    uint iteration = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    rwbuffer.Store(0, iteration);
}

// Test 2: GetCurrentLoopIterationIndex in node within loop
// CHECK-LABEL: define void @inner_loop_node
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(4, 4, 1)]
[NumThreads(64,1,1)]
void inner_loop_node(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopEntry)
{
    // Use iteration index to decide whether to loop
    uint currentIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    if (currentIter < 99) {
        ThreadNodeOutputRecords<RECORD> rec = loopEntry.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data;
        rec.Get().iteration = currentIter + 1;
        rec.OutputComplete();
    }
    
    rwbuffer.Store(currentIter * 4, input.Get().data);
}

// Test 3: Multiple calls to GetCurrentLoopIterationIndex
// CHECK-LABEL: define void @multiple_calls
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(5)]
[NumThreads(1,1,1)]
void multiple_calls(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> loopOutput)
{
    uint iter1 = GetCurrentLoopIterationIndex();
    uint iter2 = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    // Verify both return the same value
    rwbuffer.Store(0, iter1);
    rwbuffer.Store(4, iter2);
}

// Test 4: Nested loop - GetCurrentLoopIterationIndex in inner loop
// CHECK-LABEL: define void @outer_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(5)]
[NumThreads(1,1,1)]
void outer_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> innerLoop)
{
    uint outerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    ThreadNodeOutputRecords<RECORD> rec = innerLoop.GetThreadNodeOutputRecords(1);
    rec.Get().iteration = outerIter;
    rec.OutputComplete();
}

// CHECK-LABEL: define void @inner_loop_entry
[Shader("node")]
[NodeLaunch("thread")]
[NodeMaxLoopIterations(20)]
[NodeMaxRecordsPerLoopIteration(3)]
[NumThreads(1,1,1)]
void inner_loop_entry(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(3)] NodeOutput<RECORD> self,
    [MaxRecords(3)] NodeOutput<RECORD> outerLoop)
{
    uint innerIter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    // In nested loop, this returns inner loop iteration, not outer
    
    if (innerIter < 19) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().iteration = innerIter + 1;
        rec.OutputComplete();
    }
}

// Test 5: GetCurrentLoopIterationIndex in non-loop node (returns 0)
// CHECK-LABEL: define void @non_loop_with_iteration_call
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void non_loop_with_iteration_call(
    ThreadNodeInputRecord<RECORD> input)
{
    // Should return 0 when not in a loop
    uint iteration = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    rwbuffer.Store(0, iteration);
}

// Test 6: Using iteration index in record
// CHECK-LABEL: define void @iteration_in_record
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(128)]
[NodeMaxRecordsPerLoopIteration(16)]
[NumThreads(1,1,1)]
void iteration_in_record(
    [MaxRecords(16)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> loopOutput,
    [MaxRecords(16)] NodeOutput<RECORD> leafOutput)
{
    uint iter = GetCurrentLoopIterationIndex();
    // CHECK: call i32 @dx.op.getCurrentLoopIterationIndex(i32 312)
    
    uint count = input.Count();
    for (uint i = 0; i < count; i++) {
        RECORD rec = input.Get(i);
        
        if (iter < 127) {
            // Continue looping
            ThreadNodeOutputRecords<RECORD> outRec = loopOutput.GetThreadNodeOutputRecords(1);
            outRec.Get().data = rec.data + 1;
            outRec.Get().iteration = iter + 1;
            outRec.OutputComplete();
        } else {
            // Exit loop
            ThreadNodeOutputRecords<RECORD> outRec = leafOutput.GetThreadNodeOutputRecords(1);
            outRec.Get().data = rec.data;
            outRec.Get().iteration = iter;
            outRec.OutputComplete();
        }
    }
}

// Verify the opcode declaration is generated
// CHECK-DAG: declare i32 @dx.op.getCurrentLoopIterationIndex(i32)

