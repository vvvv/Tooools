// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tWV: WORLDVIEW;
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)

struct vs2ps
{
    float4 PosWVP: POSITION;
    float4 Diffuse: COLOR0;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------

float freq = 1;
float off = 0;
float4x4 Transforms[50];

vs2ps VS(
    float4 PosO  : POSITION,
    float4 TexCd : TEXCOORD0,
    int Index: TEXCOORD1)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    PosO.xyz = PosO.xzy;
    PosO.y = sin(sqrt(pow(PosO.x*freq, 2) + pow(PosO.z*freq, 2)) + off) * 0.1;

    float4x4 tWorld = Transforms[Index];
    //view direction = inverse vertexposition in viewspace
    float4 PosW = mul(PosO, tWorld);
    float4 PosV = mul(PosW, tV);

    //position (projected)
    Out.PosWVP  = mul(PosV, tP);
    float c = PosO.y*10;
    Out.Diffuse = float4(c, c, c, 1);

    return Out;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TSimpleVertex
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_2_0 VS();
        PixelShader = null;
    }
}
