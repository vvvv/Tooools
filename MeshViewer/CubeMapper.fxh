// CubeMap based Environment Mapping
// featuring:
//         - SkyBox
//         - Reflection (also used for Imagebased Specular Lighting)
//         - Reflection <- fresnel based blending -> Refraction
//         - Imagebased Diffuse Lighting
//
//all functions take their parameters (view and normal vectors) in worldspace

float MaxReflectiveness <string uiname="Maximum Reflectiveness";> = 1;
float3 ETAs <string uiname="Refraction Indices RGB";> = float3(0.48, 0.5, 0.52);

float4 SkyBoxColor(samplerCUBE Samp, float3 ViewVectorW)
{
    return texCUBE(Samp, ViewVectorW);
}

float4 ReflectiveColor(samplerCUBE Samp, float3 ViewVectorW, float3 NormalW)
{
    return texCUBE(Samp, reflect(ViewVectorW, NormalW)) * MaxReflectiveness;
}

//experimental
float4 ReflectiveLocalizedColor(samplerCUBE Samp, float3 ViewVectorL, float3 NormalL, float3 PosL)
{
    float3 Vu = normalize(ViewVectorL);
    float3 Nu = normalize(NormalL);
    float3 reflVect = normalize(reflect(Vu, Nu));
	
	reflVect = 1000*reflVect - PosL;
    return texCUBE(Samp, -reflVect) * MaxReflectiveness;
}

float4 RefractiveColor(samplerCUBE Samp, float3 ViewVectorW, float3 NormalW, float3 ETA)
{
    float r = texCUBE(Samp, refract(ViewVectorW, NormalW, ETA.x)).r;
    float g = texCUBE(Samp, refract(ViewVectorW, NormalW, ETA.y)).g;
    float b = texCUBE(Samp, refract(ViewVectorW, NormalW, ETA.z)).b;

    return float4(r, g, b, 1);
}

float4 ImageBasedDiffuseColor(samplerCUBE Samp, float3 NormalW)
{
    return texCUBE(Samp, NormalW);
}

// approximate Fresnel function
float fresnel(float NdotV, float min, float FresnelExponent)
{
   return min + (1.0-min)*pow(1.0 - max(NdotV, 0), FresnelExponent);
}