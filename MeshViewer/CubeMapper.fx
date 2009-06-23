// CubeMap based Environment Mapping
// featuring:
//         - SkyBox
//         - Reflection (bump, normal distortion)
//         - Reflection <- fresnel based blending -> Refraction
//         - image based diffuse lighting

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tWV: WORLDVIEW;
float4x4 tVP: VIEWPROJECTION;
float3 posCam : CAMERAPOSITION;

//textures
texture TexSky <string uiname="Sky CubeMap";>;
samplerCUBE SampSky = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexSky);       //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture TexReflect <string uiname="Reflection CubeMap";>;
samplerCUBE SampReflect = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexReflect);   //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture TexRefract <string uiname="Refraction CubeMap";>;
samplerCUBE SampRefract = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexRefract);   //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture TexDiffuse <string uiname="Diffuse CubeMap";>;
samplerCUBE SampDiffuse = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexDiffuse);   //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float MaxReflectiveness = 1;
float3 ETAs;

//texture transformation marked with semantic TEXTUREMATRIX to achieve symmetric transformations
float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps_SkyBox
{
    float4 PosWVP: POSITION;
    float3 ViewVectorW: TEXCOORD0;
};

struct vs2ps
{
    float4 PosWVP: POSITION;
    float3 ViewVectorW: TEXCOORD0;
    float4 ViewVectorV: TEXCOORD1;
    float3 NormW: TEXCOORD2;
    float4 NormV: TEXCOORD3;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps_SkyBox VS_SkyBox(
    float4 PosO: POSITION)
{
    //declare output struct
    vs2ps_SkyBox Out;

    //position in world space
    float4 PosW = mul(PosO, tW);
    
    //texture coordinates for skybox cubemap
    Out.ViewVectorW = PosW - posCam;

    //position in projection space
    Out.PosWVP = mul(PosW, tVP);

    return Out;
}

vs2ps VS_Reflect(
    float4 PosO: POSITION,
    float4 NormO: NORMAL)
{
    //declare output struct
    vs2ps Out;

    //position in world space
    float4 PosW = mul(PosO, tW);

    //texture coordinates for skybox cubemap
    Out.ViewVectorW = PosW - posCam;
    Out.ViewVectorV = -normalize(mul(PosO, tWV));
    
    //normal in view space
    Out.NormV = normalize(mul(NormO, tWV));
    
    //normal in world space
    //make sure NormO.w = 0, else we get artefacts when scaling the model
    NormO.w = 0;
    //the normal is a directional vector and therefore should have length=1
    Out.NormW = normalize(mul(NormO, tW));
    Out.NormV = normalize(mul(NormO, tWV));
    
    //position in projection space
    Out.PosWVP = mul(PosW, tVP);

    return Out;
}

float4 SkyBoxColor(float3 ViewVectorW)
{
    return texCUBE(SampSky, ViewVectorW);
}

float4 ReflectiveColor(float3 ViewVectorW, float3 NormalW)
{
    return texCUBE(SampReflect, reflect(ViewVectorW, NormalW));
}

float4 RefractiveColor(float3 ViewVectorW, float3 NormalW, float3 ETA)
{
    float r = texCUBE(SampRefract, refract(ViewVectorW, NormalW, ETA.x)).r;
    float g = texCUBE(SampRefract, refract(ViewVectorW, NormalW, ETA.y)).g;
    float b = texCUBE(SampRefract, refract(ViewVectorW, NormalW, ETA.z)).b;

    return float4(r, g, b, 1);
}

float4 ImageBasedDiffuseColor(float3 NormalW)
{
    return texCUBE(SampDiffuse, NormalW);
}


// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4 PS_SkyBox(vs2ps In): COLOR
{
    float4 col = texCUBE(SampSky, In.ViewVectorW);
    return col;
}

// approximate Fresnel function
float fresnel(float NdotV, float bias, float power)
{
   return bias + (1.0-bias)*pow(1.0 - max(NdotV, 0), power);
}

float4 PS_Reflect(vs2ps In): COLOR
{
    //reflective color
    float4 cReflect = ReflectiveColor(In.ViewVectorW, In.NormW);
    //scale reflection to maximum reflectiveness
    cReflect.rgb *= MaxReflectiveness;
    
    return cReflect;
}

float4 PS_ReflectRefract(vs2ps In): COLOR
{
    //reflective color
    float4 cReflect = ReflectiveColor(In.ViewVectorW, In.NormW);
    //scale reflection to maximum reflectiveness
    cReflect.rgb *= MaxReflectiveness;

    //refractive color
    float4 cRefract = RefractiveColor(In.ViewVectorW, In.NormW, ETAs);

    //blend reflection and refraction via fresnel term
    float f = fresnel(1+dot(normalize(In.ViewVectorW), In.NormW), 0.1, 5);
    float4 col = lerp(cReflect, cRefract, f);

    col.a = 1;
    return col;
}

float4 PS_Diffuse(vs2ps In): COLOR
{
    //diffuse environment color
    float4 cDiffuse = ImageBasedDiffuseColor(In.NormW);
    return cDiffuse;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TSkyBox
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_1_0 VS_SkyBox();
        PixelShader  = compile ps_1_0 PS_SkyBox();
    }
}

technique TReflect
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_Reflect();
    }
}

technique TReflectRefract
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_ReflectRefract();
    }
}

technique TDiffuseLight
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_Diffuse();
    }
}
