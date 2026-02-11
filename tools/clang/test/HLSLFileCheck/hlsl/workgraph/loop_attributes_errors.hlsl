// RUN: %dxc -T lib_6_9 %s -verify

// Tests for semantic validation errors with loop attributes

struct RECORD
{
    uint value;
};

// Error 1: NodeMaxLoopIterations without NodeMaxRecordsPerLoopIteration
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]  // expected-error{{NodeMaxLoopIterations requires NodeMaxRecordsPerLoopIteration to also be specified}}
void Error_MissingMaxRecordsPerLoop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// Error 2: NodeMaxLoopIterations exceeds maximum
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(16777215)]  // expected-error{{NodeMaxLoopIterations value 16777215 exceeds maximum of 16777214}}
[NodeMaxRecordsPerLoopIteration(1)]
void Error_MaxIterationsExceeded(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// Error 3: NodeMaxRecordsPerLoopIteration exceeds maximum
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(257)]  // expected-error{{NodeMaxRecordsPerLoopIteration value 257 exceeds maximum of 256}}
void Error_MaxRecordsPerIterationExceeded(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}



// Error 5: NodeMaxLoopIterations with zero value
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(0)]  // expected-error{{NodeMaxLoopIterations value must be greater than 0}}
[NodeMaxRecordsPerLoopIteration(1)]
void Error_ZeroIterations(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// Error 6: NodeMaxRecordsPerLoopIteration with zero value
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(10)]
[NodeMaxRecordsPerLoopIteration(0)]  // expected-error{{NodeMaxRecordsPerLoopIteration value must be greater than 0}}
void Error_ZeroRecordsPerIteration(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

// Error 7: NodeMaxRecordsPerLoopIteration without NodeMaxLoopIterations (should be allowed but ignored)
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxRecordsPerLoopIteration(4)]  // This alone should not be an error, just ignored
void NoError_OnlyMaxRecordsPerLoop(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

