/*
  2007.12.28

  written by kalle
  mostly from scratch
  for use with vvvv

  visit
  http://vvvv.org/tiki-index.php?page=kalle
  http://vvvv.org/tiki-index.php?page=kalle.Shader
*/

float4x4 tWIT : WorldInverseTranspose;
float4x4 tWVP : WorldViewProjection;
float4x4 tW   : World;
float4x4 tVI  : ViewInverse;

float4 matCOL : COLOR <String uiname="Material Color";>  = {1, 1, 1, 1};
// for refraction
float4 surfCOL : COLOR <String uiname="Surface Color";>  = {1, 1, 1, 1};
// for reflection

texture CubeTexture  ;

samplerCUBE
           Samp = sampler_state
               {
	       Texture = <CubeTexture>;
               MinFilter = Linear;
	       MagFilter = Linear;
	       MipFilter = Linear;
               };
float ETA
      <
      String uiname="Refraction Index";
      float uimin=0.0;
      float uimax=1.0;
      >
      = 0.55;

float BLEND
      <
      String uiname="Refraction Amount";
      float uimin=0.0;
      float uimax=1.0;
      >
      = 0.8;

/* data passed from vertex shader to pixel shader */

struct VS2PS
    {
    float4 HPosition	: POSITION;
    float3 WorldNormal	: TEXCOORD0;
    float3 WorldViewInv	: TEXCOORD1;
    float3 Proj: TEXCOORD2;
    };

/*********** vertex shader ******/

VS2PS VS
      (
      float3 Position	: POSITION,
      float4 Normal	: NORMAL
      )
             {
             VS2PS OUT;
                   float4 normal = normalize(Normal);
             OUT.WorldNormal = mul(normal, tWIT).xyz;

                   float4 Po = float4(Position.xyz,1);
                   float3 Pw = mul(Po, tW).xyz;

             OUT.Proj = mul(Po, -tW).xyz;
             OUT.WorldViewInv = normalize ( tVI[3].xyz - Pw ) ;
             OUT.HPosition = mul ( Po , tWVP ) ;
             return OUT;
             }


/********* common maths for pixel shader ********/


void cubetex_void
     (
     VS2PS IN,
     out float3 CubeTexContrib
     )
          {
          float3 UVW = normalize(IN.WorldNormal);
          CubeTexContrib = texCUBE ( Samp, -IN.Proj ).xyz;
          }

void calculateReflection
     (
     VS2PS IN,
     out float3 ReflectionContrib
     )
          {
          float3 Wn = normalize(IN.WorldNormal);
          float3 VIn = normalize(IN.WorldViewInv);
          float3 reflVect = -reflect(VIn,Wn);
          ReflectionContrib = texCUBE(Samp,reflVect).xyz;
          }

void calculateRefraction
     (
     VS2PS IN,
     out float3 RefractionContrib
     )
          {
          float3 Wn = normalize(IN.WorldNormal);
          float3 VIn = normalize(IN.WorldViewInv);
          float3 refracVect = refract(-VIn,Wn,ETA);
          RefractionContrib = texCUBE(Samp,refracVect).xyz;
          }

/********* pixel shader ********/

float4 PS_basic_ct  (VS2PS IN) : COLOR
      {
      float4 CubeTexColor = (1,1,1,1) ;
      cubetex_void ( IN, CubeTexColor.rgb );
      return CubeTexColor ;
      }

float4 PS_basic_coloured_ct  (VS2PS IN) : COLOR
      {
      float4 CubeTexColor = (1,1,1,1) ;
      cubetex_void ( IN, CubeTexColor.rgb );
      return CubeTexColor* matCOL ;
      }
      
      
float4 PS_Reflected_CT (VS2PS IN) : COLOR
      {
      float4 reflColor = (1,1,1,1) ;
             calculateReflection ( IN, reflColor.rgb );
             reflColor *= surfCOL;
      return reflColor ;
      }
      
      
      
float4 PS_Refracted_CT (VS2PS IN) : COLOR
      {
            float4 refrColor = (1,1,1,1) ;
            calculateRefraction ( IN, refrColor.rgb );
            refrColor *= matCOL;
      return refrColor ;
      }
      
      
float4 PS_ReflANDrefr_CT (VS2PS IN) : COLOR
      {
      float4 refrColor = (1,1,1,1) ;
             calculateRefraction ( IN, refrColor.rgb );
             refrColor *= matCOL;

      float4 reflColor = (1,1,1,1) ;
             calculateReflection ( IN, reflColor.rgb );
             reflColor *= surfCOL;

      float4 ResultColor = lerp(reflColor,refrColor,BLEND);

      return ResultColor ;
      }


/*************/

technique BasicCubeTexturing
{
	pass p0
        {
        VertexShader = compile vs_1_0 VS();
        PixelShader = compile ps_1_4 PS_basic_ct ();
	}
}

technique ColouredCubeTexturing
{
	pass p0
        {
        VertexShader = compile vs_1_0 VS();
        PixelShader = compile ps_1_4 PS_basic_coloured_ct ();
	}
}

technique SimpleReflection
{
	pass p0
        {
        VertexShader = compile vs_1_0 VS();
        PixelShader = compile ps_2_0 PS_Reflected_CT();
	}
}

technique SimpleRefraction
{
	pass p0
        {
        VertexShader = compile vs_1_0 VS();
        PixelShader = compile ps_2_0 PS_Refracted_CT();
	}
}

technique ReflectAndRefract

{
	pass p0
        {
        VertexShader = compile vs_1_0 VS();
        PixelShader = compile ps_2_0 PS_ReflANDrefr_CT();
	}
}
/***************************** eof ***/
