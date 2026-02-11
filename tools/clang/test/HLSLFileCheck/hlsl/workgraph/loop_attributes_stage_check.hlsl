// RUN: %dxc -T lib_6_9 %s -verify

// Tests that loop attributes are only allowed on node shaders

struct RECORD
{
    uint value;
};

// Error: NodeMaxLoopIterations on compute shader
[Shader("compute")]
[NumThreads(64, 1, 1)]
[NodeMaxLoopIterations(100)]  // expected-error{{NodeMaxLoopIterations is only allowed on node shaders}}
[NodeMaxRecordsPerLoopIteration(4)]  // expected-error{{NodeMaxRecordsPerLoopIteration is only allowed on node shaders}}
void ComputeShader_WithLoopAttrs()
{
}

// Error: NodeMaxLoopIterations on pixel shader
[Shader("pixel")]
[NodeMaxLoopIterations(100)]  // expected-error{{NodeMaxLoopIterations is only allowed on node shaders}}
[NodeMaxRecordsPerLoopIteration(10)]  // expected-error{{NodeMaxRecordsPerLoopIteration is only allowed on node shaders}}
float4 PixelShader_WithLoopAttrs() : SV_Target 
{
    return float4(0,0,0,0);
}

// Error: NodeMaxLoopIterations on vertex shader
[Shader("vertex")]
[NodeMaxLoopIterations(100)]  // expected-error{{NodeMaxLoopIterations is only allowed on node shaders}}
[NodeMaxRecordsPerLoopIteration(10)]  // expected-error{{NodeMaxRecordsPerLoopIteration is only allowed on node shaders}}
float4 VertexShader_WithLoopAttrs() : SV_Position 
{
    return float4(0,0,0,0);
}

// Valid: Node shader with loop attributes
[Shader("node")]
[NodeLaunch("thread")]
[NodeIsProgramEntry]
[NodeMaxLoopIterations(100)]
[NodeMaxRecordsPerLoopIteration(4)]
void ValidNodeShader(
    ThreadNodeInputRecord<RECORD> input,
    [MaxRecords(1)] NodeOutput<RECORD> output
)
{
}

