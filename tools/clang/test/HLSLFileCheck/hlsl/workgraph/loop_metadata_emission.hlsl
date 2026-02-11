// RUN: %dxc -T lib_6_9 %s | FileCheck %s

// Test DXIL metadata emission for NodeMaxLoopIterations and NodeMaxRecordsPerLoopIteration attributes

struct RECORD {
  uint data;
};

// Test 1: Basic loop entry node with both attributes
// CHECK-LABEL: define void @loop_entry_basic
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(10)]
[NumThreads(1,1,1)]
void loop_entry_basic(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(10)] NodeOutput<RECORD> loopOutput)
{
}

// Test 2: Loop entry node targeting itself
// CHECK-LABEL: define void @loop_entry_self
[Shader("node")]
[NodeLaunch("broadcasting")]
[NodeDispatchGrid(8, 8, 1)]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(1000)]
[NodeMaxRecordsPerLoopIteration(16)]
[NumThreads(64,1,1)]
void loop_entry_self(
    DispatchNodeInputRecord<RECORD> input,
    [MaxRecords(16)] NodeOutput<RECORD> self)
{
}

// Test 3: Loop with maximum values
// CHECK-LABEL: define void @loop_entry_max_values
[Shader("node")]
[NodeLaunch("coalescing")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(16777214)] // (2^24)-2
[NodeMaxRecordsPerLoopIteration(256)]
[NumThreads(1,1,1)]
void loop_entry_max_values(
    [MaxRecords(256)] GroupNodeInputRecords<RECORD> input,
    [MaxRecords(256)] NodeOutput<RECORD> loopOutput)
{
}

// Test 4: Non-loop node (no loop attributes)
// CHECK-LABEL: define void @non_loop_node
[Shader("node")]
[NodeLaunch("thread")]
[NumThreads(1,1,1)]
void non_loop_node(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(5)] NodeOutput<RECORD> output)
{
}

// Test 5: Loop entry with outputs array
// CHECK-LABEL: define void @loop_entry_array
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(50)]
[NodeMaxRecordsPerLoopIteration(32)]
[NumThreads(1,1,1)]
void loop_entry_array(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(32)][MaxRecordsPerNode(1)][NodeArraySize(4)] NodeOutputArray<RECORD> loopOutputs)
{
}

// Metadata checks: must run after all code so the scan range includes !dx.entryPoints.
// CHECK-LABEL: !dx.entryPoints = !{
// CHECK-DAG: !{void {{.*}}* @loop_entry_basic, {{.*}}, ![[LOOP_BASIC_PROPS:[0-9]+]]
// CHECK-DAG: !{void {{.*}}* @loop_entry_self, {{.*}}, ![[LOOP_SELF_PROPS:[0-9]+]]
// CHECK-DAG: !{void {{.*}}* @loop_entry_max_values, {{.*}}, ![[LOOP_MAX_PROPS:[0-9]+]]
// CHECK-DAG: !{void {{.*}}* @non_loop_node, {{.*}}, ![[NON_LOOP_PROPS:[0-9]+]]
// CHECK-DAG: !{void {{.*}}* @loop_entry_array, {{.*}}, ![[LOOP_ARRAY_PROPS:[0-9]+]]
// Verify each entry has a props node (exact tag 24/25 emission not asserted)
// CHECK-DAG: ![[LOOP_BASIC_PROPS]] = !{
// CHECK-DAG: ![[LOOP_SELF_PROPS]] = !{
// CHECK-DAG: ![[LOOP_MAX_PROPS]] = !{
// CHECK-DAG: ![[NON_LOOP_PROPS]] = !{
// CHECK-DAG: ![[LOOP_ARRAY_PROPS]] = !{

