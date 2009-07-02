// CubeMap based Environment Mapping
// featuring:
//         - SkyBox
//         - Reflection (bump, normal distortion)
//         - Reflection <- fresnel based blending -> Refraction
//         - image based diffuse lighting

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------
#include "CubeMapper.fxh"

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tWIT: WORLDINVERSETRANSPOSE;
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tWV: WORLDVIEW;
float4x4 tVP: VIEWPROJECTION;
float3 posCam : CAMERAPOSITION;
float4x4 tLight;
float4x4 tLightIT;

//textures
texture TexEnvironment <string uiname="Environment CubeMap";>;
samplerCUBE SampEnvironment = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexEnvironment);       //apply a texture to the sampler
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
    float3 ViewVectorL: TEXCOORD4;
    float3 PosL: TEXCOORD5;
    float3 NormalL: TEXCOORD6;
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
    float4 NormalO: NORMAL)
{
    //declare output struct
    vs2ps Out = (vs2ps) 0;

    //position in world space
    float4 PosW = mul(PosO, tW);

    //texture coordinates for skybox cubemap
    Out.ViewVectorW = PosW - posCam;
    Out.ViewVectorV = -normalize(mul(PosO, tWV));
    
    //normal in view space
    Out.NormV = normalize(mul(NormalO, tWV));
    
    //normal in world space
    //make sure NormO.w = 0, else we get artefacts when scaling the model
    NormalO.w = 0;
    //the normal is a directional vector and therefore should have length=1
    Out.NormW = normalize(mul(NormalO, tW));
    Out.NormV = normalize(mul(NormalO, tWV));
    
    //position in projection space
    Out.PosWVP = mul(PosW, tVP);
    
    //localized ibl
    float4 nw = mul(NormalO, tWIT);
    Out.NormalL = mul(nw, tLightIT);

    float4 posL = mul(PosW, tLight);
    Out.PosL = posL.xyz;

    float4 camPosL = mul(float4(posCam, 1), tLight);
    Out.ViewVectorL = camPosL - posL;

    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4 PS_SkyBox(vs2ps In): COLOR
{
    float4 col = texCUBE(SampEnvironment, In.ViewVectorW);
    return col;
}

float4 PS_Reflect(vs2ps In): COLOR
{
    //reflective color
    float4 cReflect = ReflectiveColor(SampEnvironment, In.ViewVectorW, In.NormW);
    //scale reflection to maximum reflectiveness
    cReflect.rgb *= MaxReflectiveness;
    
    return cReflect;
}



float4 PS_ReflectLocalized(vs2ps In): COLOR
{
    //reflective color
    float3 Vu = normalize(In.ViewVectorL);
    float3 Nu = normalize(In.NormalL);
    float3 reflVect = normalize(reflect(Vu, Nu));

   /* float b = -2.0 * dot(reflVect, In.PosL);
    float c = dot(In.PosL, In.PosL) - 1.0;
    float discrim = b*b - 4.0*c;
         */
    bool hasIntersects = true;
    float4 reflColor = float4(1, 0, 0, 1);
  /*  if (discrim < 0)
    {
       hasIntersects = ((abs(sqrt(discrim) - b) / 2.0) > 0.00001);
    }      */
    if (hasIntersects)
    {
       reflVect = 1000*reflVect - In.PosL;
       //reflVect.y *= -1;
       reflColor = texCUBE(SampEnvironment, -reflVect);
    }
    return reflColor;
}

float4 PS_ReflectRefract(vs2ps In): COLOR
{
    //reflective color
    float4 cReflect = ReflectiveColor(SampEnvironment, In.ViewVectorW, In.NormW);
    //scale reflection to maximum reflectiveness
    cReflect.rgb *= MaxReflectiveness;

    //refractive color
    float4 cRefract = RefractiveColor(SampRefract, In.ViewVectorW, In.NormW, ETAs);

    //blend reflection and refraction via fresnel term
    float f = fresnel(1+dot(normalize(In.ViewVectorW), In.NormW), 0.1, 5);
    float4 col = lerp(cReflect, cRefract, f);

    col.a = 1;
    return col;
}

float4 PS_Diffuse(vs2ps In): COLOR
{
    //diffuse environment color
    float4 cDiffuse = ImageBasedDiffuseColor(SampEnvironment, In.NormW);
    return cDiffuse;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TSkyBox
{
    pass P0
    {
        VertexShader = compile vs_1_0 VS_SkyBox();
        PixelShader  = compile ps_1_0 PS_SkyBox();
    }
}

technique TReflect
{
    pass P0
    {
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_Reflect();
    }
}

technique TReflectLocalized
{
    pass P0
    {
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_ReflectLocalized();
    }
}

technique TReflectRefract
{
    pass P0
    {
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_ReflectRefract();
    }
}

technique TDiffuseLight
{
    pass P0
    {
        VertexShader = compile vs_1_1 VS_Reflect();
        PixelShader  = compile ps_2_0 PS_Diffuse();
    }
}
