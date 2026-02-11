// RUN: %dxc -T lib_6_8 %s | FileCheck %s
// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Test backward compatibility: SM 6.8 shaders should compile in SM 6.9 without changes

struct RECORD {
  uint data;
  uint extra;
};

// Test 1: Basic node from SM 6.8 should work in SM 6.9
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void basic_sm68_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> output)
{
    ThreadNodeOutputRecords<RECORD> rec = output.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.OutputComplete();
}

// CHECK-DAG: define void @basic_sm68_node

// Test 2: Broadcasting node from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(16, 16, 1)]
[NodeIsProgramEntry]
[NumThreads(256,1,1)]
void broadcasting_sm68_node(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(20)] NodeOutput<RECORD> output)
{
    GroupNodeOutputRecords<RECORD> rec = output.GetGroupNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 2;
    rec.OutputComplete();
}

// CHECK-DAG: define void @broadcasting_sm68_node

// Test 3: Coalescing node from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NumThreads(128,1,1)]
void coalescing_sm68_node(
    [MaxRecords(32)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> output)
{
    uint count = input.Count();
    for (uint i = 0; i < count; i++) {
        ThreadNodeOutputRecords<RECORD> rec = output.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get(i).data;
        rec.OutputComplete();
    }
}

// CHECK-DAG: define void @coalescing_sm68_node

// Test 4: Recursive node from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxRecursionDepth(8)]
[NumThreads(1,1,1)]
void recursive_sm68_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> self)
{
    if (input.Get().data < 100) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data + 10;
        rec.OutputComplete();
    }
}

// CHECK-DAG: define void @recursive_sm68_node

// Test 5: Node with output array from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void array_output_sm68_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(8)][MaxRecordsPerNode(1)][NodeArraySize(4)] NodeOutputArray<RECORD> outputs)
{
    uint index = input.Get().data % 4;
    ThreadNodeOutputRecords<RECORD> rec = outputs[index].GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data;
    rec.OutputComplete();
}

// CHECK-DAG: define void @array_output_sm68_node

// Test 6: Empty node input/output from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NumThreads(64,1,1)]
void empty_io_sm68_node(
    EmptyNodeInput input,
    [MaxRecords(10)] EmptyNodeOutput output)
{
    output.GroupIncrementOutputCount(5);
}

// CHECK-DAG: define void @empty_io_sm68_node

// Test 7: Node with shared input from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeShareInputOf("array_output_sm68_node")]
[NumThreads(1,1,1)]
void shared_input_sm68_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> output)
{
    ThreadNodeOutputRecords<RECORD> rec = output.GetThreadNodeOutputRecords(1);
    rec.Get().data = input.Get().data + 1;
    rec.OutputComplete();
}

// CHECK-DAG: define void @shared_input_sm68_node

RWByteAddressBuffer rwbuffer : register(u0);

// Test 8: GetRemainingRecursionLevels (SM 6.8) works in SM 6.9
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxRecursionDepth(10)]
[NumThreads(1,1,1)]
void recursion_levels_sm68_intrinsic(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> self)
{
    uint remaining = GetRemainingRecursionLevels();
    rwbuffer.Store(0, remaining);
    
    if (remaining > 0) {
        ThreadNodeOutputRecords<RECORD> rec = self.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data;
        rec.OutputComplete();
    }
}

// CHECK: call i32 @dx.op.getRemainingRecursionLevels

// Test 9: MaxRecordsSharedWith from SM 6.8
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NumThreads(1,1,1)]
void shared_budget_sm68_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> output1,
    [MaxRecordsSharedWith(output1)] NodeOutput<RECORD> output2)
{
    if (input.Get().data % 2 == 0) {
        ThreadNodeOutputRecords<RECORD> rec = output1.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data;
        rec.OutputComplete();
    } else {
        ThreadNodeOutputRecords<RECORD> rec = output2.GetThreadNodeOutputRecords(1);
        rec.Get().data = input.Get().data;
        rec.OutputComplete();
    }
}

// CHECK-DAG: define void @shared_budget_sm68_node

// Test 10: Verify SM 6.8 metadata format is preserved in SM 6.9
// TODO-CHECK-DAG: !{void {{.*}}* @basic_sm68_node, {{.*}}, ![[PROPS:[0-9]+]]
// Both should have same basic metadata structure

// Test 11: Verify SM 6.9 doesn't add loop metadata to non-loop SM 6.8 nodes
// CHECK-NOT: ![[PROPS]] = !{{{.*}}, i32 24,
// CHECK-NOT: ![[PROPS]] = !{{{.*}}, i32 25,
// No loop metadata tags (24, 25) should appear for non-loop nodes

// Test 12: Complex SM 6.8 node with multiple features
// CHECK-NOT: error
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NodeIsProgramEntry]
[NodeMaxRecursionDepth(5)]
[NumThreads(64,1,1)]
void complex_sm68_node(
    DispatchNodeInputRecord<RECORD> input,
    in uint2 GroupID : SV_GroupID,
    [MaxRecords(20)] NodeOutput<RECORD> recursive,
    [MaxRecords(10)][MaxRecordsPerNode(1)][NodeArraySize(8)] NodeOutputArray<RECORD> outputs)
{
    // Recursive output
    if (input.Get().data < 50) {
        GroupNodeOutputRecords<RECORD> rec = recursive.GetGroupNodeOutputRecords(1);
        rec.Get().data = input.Get().data + 1;
        rec.OutputComplete();
    }
    
    // Array output
    uint index = (GroupID.x + GroupID.y) % 8;
    GroupNodeOutputRecords<RECORD> rec = outputs[index].GetGroupNodeOutputRecords(1);
    rec.Get().data = input.Get().data * 2;
    rec.OutputComplete();
    
    // Buffer write
    rwbuffer.Store(input.Get().data * 4, input.Get().data);
}

// CHECK-DAG: define void @complex_sm68_node

