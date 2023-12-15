Shader "Custom/URPAnimationLitShader"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Float) = 1
        [HideInInspector]_boneTextureBlockWidth("_boneTextureBlockWidth", int) = 0
		[HideInInspector]_boneTextureBlockHeight("_boneTextureBlockHeight", int) = 0
		[HideInInspector]_boneTextureWidth("_boneTextureWidth", int) = 0
		[HideInInspector]_boneTextureHeight("_boneTextureHeight", int) = 0
    }
    SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }
        LOD 200

        Pass
        {
        	Name "ForwardLit"
        	Tags{ "LightMode" = "UniversalForward" }
        	
            Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			ZTest Less
			Cull Back
            
            HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 2.0

            // Universal Pipeline keywords
			// #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			// #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			// #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			// #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			// #pragma multi_compile_fragment _ _SHADOWS_SOFT
			// #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
			// #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			// #pragma multi_compile _ SHADOWS_SHADOWMASK
			//
			// #pragma shader_feature_local _NORMALMAP
			// #pragma shader_feature_local_fragment _ALPHATEST_ON
			// #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
			// #pragma shader_feature_local_fragment _EMISSION
			// #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
			// #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			// #pragma shader_feature_local_fragment _OCCLUSIONMAP
			// #pragma shader_feature_local _PARALLAXMAP
			// #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
			// #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			// #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
			// #pragma shader_feature_local_fragment _SPECULAR_SETUP
			// #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
			// Unity defined keywords
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_fog
			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
            
            #pragma vertex vertn
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_forwardadd

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "URPAnimationInstancingBaseCustom.hlsl"

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPosition : TEXCOORD1;
            	float3 normal   : NORMAL;
                float3 tangent  : TEXCOORD2;
                float3 biTangent    : TEXCOOORD3;
            	float4 shadowCoord  : TEXCOORD4;
            	float4 fogCoord : TEXCOORD5;
            };

            v2f vertn (appdata v)
            {
                v2f o;
            	
                UNITY_SETUP_INSTANCE_ID(v);

            	vert(v);
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.worldPosition = TransformObjectToWorld(v.vertex.xyz);
            	o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldDir(v.tangent.xyz);
                o.biTangent = cross(o.normal, o.tangent) * v.tangent.w;
            	o.shadowCoord = TransformWorldToShadowCoord(o.worldPosition);
            	o.fogCoord = ComputeFogFactor(o.vertex.z);
                
                return o;
            }

            half3 AdditionalLighting(Light light, half3 normalWS)
			{
				half dotNL = dot(normalWS, light.direction) * 0.5 + 0.5;
				return light.color * light.distanceAttenuation * light.shadowAttenuation * dotNL;
			}

            float4 frag (v2f input) : SV_Target
            {
				half4 color = _MainTex.Sample(sampler_MainTex, input.uv) * _Color;

            	float3 NormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
                float3x3 tbnMatrix = float3x3(input.tangent, input.biTangent, input.normal);
                float3 normalWS = normalize(mul(NormalTS, tbnMatrix));

				Light mainLight = GetMainLight(input.shadowCoord);
				half3 lighting = AdditionalLighting(mainLight, normalWS);

            	int additionalLightsCount = GetAdditionalLightsCount();
				for (int i = 0; i < additionalLightsCount; ++i)
                {
                    Light light = GetAdditionalLight(i, input.worldPosition);
                    lighting += AdditionalLighting(light, normalWS);
                }

            	float nl = clamp(dot(input.normal,normalize(_MainLightPosition.xyz)), 0.2, 1.0);

				color = float4(color.rgb * nl * lighting, color.a);
            	color.rgb = MixFog(color.rgb, input.fogCoord.x);
            	
				return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{ "LightMode" = "ShadowCaster" }
            
            ZWrite On
			ZTest LEqual
			//ColorMask 0
			Cull Back
            
            HLSLPROGRAM

            #pragma exclude_renderers gles gles3 glcore
            #pragma target 2.0

            // -------------------------------------
			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON
            
            #pragma vertex vertn
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_shadowcaster

            #include "UnityCG.cginc"
            #include "URPAnimationInstancingBaseCustom.hlsl"

            struct v2f
            {
                V2F_SHADOW_CASTER;
            };
            
            v2f vertn(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                vert(v);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }

            ENDHLSL
        }
    	
    	Pass
		{
			Name "DepthOnly"
			Tags{"LightMode" = "DepthOnly"}

			ZWrite On
			ColorMask 0
			Cull Back

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 2.0

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
			
			ENDHLSL
		}
    }
}