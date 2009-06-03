// this is a very basic template. use it to start writing your own effects.
// if you want effects with lighting start from one of the GouraudXXXX or PhongXXXX effects

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;
float4x4 tWVP: WORLDVIEWPROJECTION;

//Source 1 texture and sampler
texture Src01 <string uiname="Source 1";>;
sampler Src01Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Src01);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

// Source 2 texture and sampler
texture Src02<string uiname="Source 2";>;
sampler Src02Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Src02);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = Mirror;
    AddressV = Mirror;
};

//source transformation
float4x4 tSrc01: TEXTUREMATRIX <string uiname="Source 1 Transform";>;

//mask transformation
float4x4 tSrc02: TEXTUREMATRIX <string uiname="Source 2 Transform";>;

//pin for the amount of mask to use as alpha
float Src02Alpha
<
    string uiname="Source 2 Transparency";
    float uimin=0.0;
    float uimax=1.0;
> = 0.0;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos  : POSITION;
    float2 Src01Cd : TEXCOORD0;
    float2 Src02Cd : TEXCOORD1;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 PosO  : POSITION,
    float4 Src01Cd : TEXCOORD0,
    float4 Src02Cd : TEXCOORD1)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.Pos = mul(PosO, tWVP);
    
    //transform texturecoordinates
    Out.Src01Cd = mul(Src01Cd, tSrc01);

    //transform the mask texture cordinates
    Out.Src02Cd = mul(Src01Cd, tSrc02);
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

/* ----------------------------------------------
 * psBlend
 * straight blend
 * ----------------------------------------------*/
float4 psBlend(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    
    outColor = lerp(src02, src01, 1-Src02Alpha);
    
    return outColor;
}

float4 psColorAsAlpha(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    
    float lumi = src02.r * 0.222 + src02.g * 0.707 + src02.b * 0.071;

    outColor = lerp(src01, src02, Src02Alpha * lumi);

    return outColor;
}

float4 psColorAsInverseAlpha(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);

    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);

    float lumi = src02.r * 0.222 + src02.g * 0.707 + src02.b * 0.071;

    outColor = lerp(src01, src02, Src02Alpha * (1-lumi));

    return outColor;
}


/* ----------------------------------------------
 * psMultiply
 * Multiply Source 2 and Source 1
 * ----------------------------------------------*/
 float4 psMultiply(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);

    src02.r = src02.r * src01.r;
    src02.g = src02.g * src01.g;
    src02.b = src02.b * src01.b;
    
    outColor.r = lerp(src02.r, src01.r, 1-Src02Alpha);
    outColor.g = lerp(src02.g, src01.g, 1-Src02Alpha);
    outColor.b = lerp(src02.b, src01.b, 1-Src02Alpha);
    outColor.a = lerp(src02.a, src01.a, 1-Src02Alpha);

    return outColor;
}
/* ----------------------------------------------
 * psScreen
 * Opposite of Multiply
 * f(a,b) = 1 - (1-a) * (1-b)
 *
 * ----------------------------------------------*/
 float4 psScreen(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);

    src02 = 1.0 - (1.0-(src01)) * (1.0-(src02));
    outColor = lerp(src02, src01, 1-Src02Alpha);

    return outColor;
}

/* ----------------------------------------------
 * psDarken
 * Take only the darkest colors from the 2 videos
 * ----------------------------------------------*/
 float4 psDarken(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};
    
    temp.r = (src01.r < src02.r) ? src01.r : src02.r;
    temp.g = (src01.g < src02.g) ? src01.g : src02.g;
    temp.b = (src01.b < src02.b) ? src01.b : src02.b;

    outColor = lerp(temp, src01, 1-Src02Alpha);
    return outColor;
}
/* ----------------------------------------------
 * psLighten
 * Take only the lightest colors from the 2
 * textures
 * ----------------------------------------------*/
 float4 psLighten(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};
    
    temp.r = (src01.r > src02.r) ? src01.r : src02.r;
    temp.g = (src01.g > src02.g) ? src01.g : src02.g;
    temp.b = (src01.b > src02.b) ? src01.b : src02.b;
    
    outColor = lerp(temp, src01, 1-Src02Alpha);
    return outColor;
}
/* ----------------------------------------------
 * psDifference
 * the difference of the 2 textures
 * f(a,b) = |a - b|
 *
 * ----------------------------------------------*/
 float4 psDifference(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = abs(src01.r-src02.r);
    temp.g = abs(src01.g-src02.g);
    temp.b = abs(src01.b-src02.b);

    outColor = lerp(temp, src01, 1-Src02Alpha);
    return outColor;
}
/* ----------------------------------------------
 * psExclusion
 * the exclusion of the 2 textures
 * f(a,b) = a + b - 2ab
 *
 * ----------------------------------------------*/
 float4 psExclusion(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};
    
    temp.r = src01.r + src02.r - (2*(src01.r*src02.r));
    temp.g = src01.g + src02.g - (2*(src01.g*src02.g));
    temp.b = src01.b + src02.b - (2*(src01.b*src02.b));

    outColor = lerp(temp, src01, 1-Src02Alpha);
    return outColor;
}
/* ----------------------------------------------
 * psOverlay
 * overlay of the 2 textures
 * f(a,b) =  2ab (for a < 0.5)
 *           1 - 2 * (1 - a) * (1 - b) (else)
 *
 *
 * ----------------------------------------------*/
 float4 psOverlay(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};
    
    temp.r = (src01.r < 0.5) ?
           (2*(src01.r*src02.r)) : 1 - (2*((1-src01.r) * (1-src02.r)));

    temp.g = (src01.g < 0.5) ?
           (2*(src01.g*src02.g)) : 1 - (2*((1-src01.g) * (1-src02.g)));

    temp.b = (src01.b < 0.5) ?
           (2*(src01.b*src02.b)) : 1 - (2*((1-src01.b) * (1-src02.b)));

    outColor = lerp(temp, src01, 1-Src02Alpha);
    return outColor;
}
/* ----------------------------------------------
 * psHardlight
 * overlay of the 2 textures
 * f(a,b) =  2ab (for b < 0.5)
 *           1 - 2 * (1 - a) * (1 - b) (else)
 *
 *
 * ----------------------------------------------*/
 float4 psHardlight(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};
    
    temp.r = (src02.r < 0.5) ?
           (2*(src01.r*src02.r)) : 1 - (2*((1-src01.r) * (1-src02.r)));
           
    temp.g = (src02.g < 0.5) ?
           (2*(src01.g*src02.g)) : 1 - (2*((1-src01.g) * (1-src02.g)));
           
    temp.b = (src02.b < 0.5) ?
           (2*(src01.b*src02.b)) : 1 - (2*((1-src01.b) * (1-src02.b)));

    outColor = lerp(temp, src01, 1-Src02Alpha);
    return outColor;
}
//
/* ----------------------------------------------
 * psSoftlight
 * overlay of the 2 textures
 * f(a,b) = 2ab + a^2 - 2a^2b
 *
 * ----------------------------------------------*/
 float4 psSoftlight(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = 2*(src01.r*src02.r) + src01.r*src01.r - 2*(pow(src01.r,2)*src02.r);
    temp.g = 2*(src01.g*src02.g) + src01.g*src01.g - 2*(pow(src01.g,2)*src02.g);
    temp.b = 2*(src01.b*src02.b) + src01.b*src01.b - 2*(pow(src01.b,2)*src02.b);

    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}
/* ----------------------------------------------
 * psDodge
 * overlay of the 2 textures
 * f(a,b) = a / (1 - b)
 * need to be clipped
 * ----------------------------------------------*/
 float4 psDodge(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = (src02.r == 1.0) ? 1.0 : src01.r / (1.0 - src02.r);
    temp.g = (src02.g == 1.0) ? 1.0 : src01.g / (1.0 - src02.g);
    temp.b = (src02.b == 1.0) ? 1.0 : src01.b / (1.0 - src02.b);
    
    if (temp.r > 1.0){temp.r = 1.0;}
    if (temp.g > 1.0){temp.g = 1.0;}
    if (temp.b > 1.0){temp.b = 1.0;}

    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

/* ----------------------------------------------
 * psBurn
 *
 * f(a,b) = 1 - (1 - a) / b
 * need to be clipped
 * ----------------------------------------------*/
 float4 psBurn(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = (src02.r == 0.0) ? 0.0 :  1.0 - (1.0 - src01.r) / src02.r;
    temp.g = (src02.g == 0.0) ? 0.0 :  1.0 - (1.0 - src01.g) / src02.g;
    temp.b = (src02.b == 0.0) ? 0.0 :  1.0 - (1.0 - src01.b) / src02.b;

    if (temp.r < 0.0){temp.r = 0.0;}
    if (temp.g < 0.0){temp.g = 0.0;}
    if (temp.b < 0.0){temp.b = 0.0;}

    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}
// non-photoshop pixel shaders
// http://www.pegtop.net/delphi/articles/blendmodes/quadratic.htm

/*
 * reflect
 * f(source01,source02) = source01^2 / (1 - source02)
 */
float4 psReflect(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = (src02.r == 1.0) ? 1.0 : (src01.r*src01.r) / (1-src02.r);
    temp.g = (src02.g == 1.0) ? 1.0 : (src01.g*src01.g) / (1-src02.g);
    temp.b = (src02.b == 1.0) ? 1.0 : (src01.b*src01.b) / (1-src02.b);

    if (temp.r > 1.0){temp.r = 1.0;}
    if (temp.g > 1.0){temp.g = 1.0;}
    if (temp.b > 1.0){temp.b = 1.0;}
    
    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

// non-photoshop pixel shaders
// http://www.pegtop.net/delphi/articles/blendmodes/quadratic.htm

/*
 * Glow
 * f(source01,source02) = source02^2 / (1 - source01)
 */
float4 psGlow(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = (src02.r == 1.0) ? 1.0 : (src02.r*src02.r) / (1-src01.r);
    temp.g = (src02.g == 1.0) ? 1.0 : (src02.g*src02.g) / (1-src01.g);
    temp.b = (src02.b == 1.0) ? 1.0 : (src02.b*src02.b) / (1-src01.b);

    if (temp.r > 1.0){temp.r = 1.0;}
    if (temp.g > 1.0){temp.g = 1.0;}
    if (temp.b > 1.0){temp.b = 1.0;}
    
    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

/*
 * Freeze
 * f(source01,source02) = 1- ((1 - source01)^2 / source02)
 */
float4 psFreeze(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = (src02.r == 0.0) ? 0.0 : 1-(1-(src01.r*src01.r)) / src02.r;
    temp.g = (src02.g == 0.0) ? 0.0 : 1-(1-(src01.g*src01.g)) / src02.g;
    temp.b = (src02.b == 0.0) ? 0.0 : 1-(1-(src01.b*src01.b)) / src02.b;

    if (temp.r < 0.0){temp.r = 0.0;}
    if (temp.g < 0.0){temp.g = 0.0;}
    if (temp.b < 0.0){temp.b = 0.0;}

    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

/*
 * Heat
 * f(source01,source02) = 1- ((1 - source02)^2 / source01)
 */
float4 psHeat(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp.r = (src01.r == 0.0) ? 0.0 : 1-(1-(src02.r*src02.r)) / src01.r;
    temp.g = (src01.g == 0.0) ? 0.0 : 1-(1-(src02.g*src02.g)) / src01.g;
    temp.b = (src01.b == 0.0) ? 0.0 : 1-(1-(src02.b*src02.b)) / src01.b;

    if (temp.r < 0.0){temp.r = 0.0;}
    if (temp.g < 0.0){temp.g = 0.0;}
    if (temp.b < 0.0){temp.b = 0.0;}

    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

/*
 * add
 * source 1 + source 2
 */
float4 psAdd(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp = src01 + src02;

    if (temp.r > 1.0){temp.r = 1.0;}
    if (temp.g > 1.0){temp.g = 1.0;}
    if (temp.b > 1.0){temp.b = 1.0;}
    
    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

/*
 * add
 * source 1 + source 2
 */
float4 psSubtract(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    //source texture lookup
    float4 src01 = tex2D(Src01Samp, In.Src01Cd);
    // the mask texture lookup
    float4 src02 = tex2D(Src02Samp, In.Src02Cd);
    float4 temp = {0.0,0.0,0.0,1.0};

    temp = src01 - src02;
    if (temp.r < 0.0){temp.r = 0.0;}
    if (temp.g < 0.0){temp.g = 0.0;}
    if (temp.b < 0.0){temp.b = 0.0;}
    
    outColor = lerp(temp, src01, 1-Src02Alpha);

    return outColor;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique Blend
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psBlend();
    }
}

technique ColorAsAlphaBlend
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psColorAsAlpha();
    }
}

technique ColorAsInverseAlphaBlend
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psColorAsInverseAlpha();
    }
}


technique Multiply
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psMultiply();
    }
}

technique Screen
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psScreen();
    }
}

technique Darken
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psDarken();
    }
}

technique Lighten
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psLighten();
    }
}

technique Difference
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psDifference();
    }
}


technique Exclusion
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psExclusion();
    }
}


technique Overlay
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psOverlay();
    }
}

technique Hardlight
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psHardlight();
    }
}

technique Softlight
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psSoftlight();
    }
}

technique Dodge
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psDodge();
    }
}

technique Burn
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psBurn();
    }
}

technique Reflect
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psReflect();
    }
}

technique Glow
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psGlow();
    }
}

technique Freeze
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psFreeze();
    }
}

technique Heat
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psHeat();
    }
}

technique Add
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psAdd();
    }
}

technique Subtract
{
    pass  P0
    {
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_2_0 psSubtract();
    }
}

technique TFixedFunction
{
    pass P0
    {
        //transforms
        WorldTransform[0]   = (tW);
        ViewTransform       = (tV);
        ProjectionTransform = (tP);

        //texturing
        Sampler[0] = (Src01Samp);
        TextureTransform[0] = (tSrc01);
        TexCoordIndex[0] = 0;
        TextureTransformFlags[0] = COUNT2;
        //Wrap0 = U;  // useful when mesh is round like a sphere
        
        Lighting       = FALSE;

        //shaders
        VertexShader = NULL;
        PixelShader  = NULL;
    }
}
