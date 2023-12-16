Shader "Custom/URPAnimationLitShader"
{
    Properties
    {
    	[Header(Base)]
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Texture", 2D) = "white" {}
    	
    	[Space(20)][Header(Normal)]
    	[NoScaleOffset][Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Float) = 1
    	
    	[Space(20)][Header(Emission)]
    	[Toggle(_EMISSION_ON)] _EMISSION_ON("Emission On", Float) = 0
    	[NoScaleOffset] _EmissionMap("Emission Map", 2D) = "black" {}
		[HDR] _EmissionColor("Emission Color", Color) = (0, 0, 0)
    	
        [Space(20)][Header(Smoothness)]
    	[Toggle(_SMOOTHNESS_ON)] _SMOOTHNESS_ON("Smoothness On", Float) = 0
    	_Smoothness("Smoothness", Float) = 30
    	
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
			#pragma shader_feature_local _ _MAIN_LIGHT_SHADOWS
			#pragma shader_feature_local _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma shader_feature_local _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma shader_feature_local _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma shader_feature_local _ _SHADOWS_SOFT
			//#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
			//#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma shader_feature_local _ SHADOWS_SHADOWMASK
			
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local_fragment _EMISSION
			//#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
			//#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			//#pragma shader_feature_local_fragment _OCCLUSIONMAP
			//#pragma shader_feature_local _PARALLAXMAP
			//#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
			#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			//#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
			#pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
			#pragma shader_feature_local_fragment _SPECULAR_SETUP
			//#pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
			// Unity defined keywords
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_fog
			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma shader_feature_local _EMISSION_ON
            #pragma shader_feature_local _SMOOTHNESS_ON
            
            #pragma vertex vertn
            #pragma fragment frag
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
            	float3 viewDirection : TEXCOORD2;
            	float3 normal   : NORMAL;
                float3 tangent  : TEXCOORD3;
                float3 biTangent    : TEXCOOORD4;
            	float4 shadowCoord  : TEXCOORD5;
            	float4 fogCoord : TEXCOORD6;
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
            	o.viewDirection = normalize(_WorldSpaceCameraPos.xyz - o.worldPosition.xyz);
                o.tangent = TransformObjectToWorldDir(v.tangent.xyz);
                o.biTangent = cross(o.normal, o.tangent) * v.tangent.w;
            	o.shadowCoord = TransformWorldToShadowCoord(o.worldPosition);
            	o.fogCoord = ComputeFogFactor(o.vertex.z);
                
                return o;
            }

            half3 AdditionalLighting(Light light, half3 normalWS)
			{
				half dotNL = dot(normalWS, light.direction) * 0.5 + 0.5;
				return light.color * dotNL * light.distanceAttenuation * light.shadowAttenuation;
			}
            
            float4 frag (v2f i) : SV_Target
            {
				half4 color = _MainTex.Sample(sampler_MainTex, i.uv) * _Color;

            	#if defined(_EMISSION_ON)
            		half3 emission = tex2Dlod(sampler_EmissionMap, float4(i.uv, 0, 1)).rgb;
            		color.rgb += emission * _EmissionColor;
				#endif
            	
            	float3 NormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv));
                float3x3 tbnMatrix = float3x3(i.tangent, i.biTangent, i.normal);
                float3 normalWS = normalize(mul(NormalTS, tbnMatrix)) * _NormalScale;

				Light mainLight = GetMainLight(i.shadowCoord);
            	half3 lighting = AdditionalLighting(mainLight, normalWS);

            	half3 ambient = SampleSH(normalWS);
            	color.rgb *= ambient;

				#if defined(_SMOOTHNESS_ON)
            		half3 reflectDirection = reflect(-mainLight.direction, normalWS);
	                half spec = saturate(dot(reflectDirection, i.viewDirection));
	                spec = pow(spec, _Smoothness);
            		color.rgb += spec;
				#endif

            	int additionalLightsCount = GetAdditionalLightsCount();
				for (int index = 0; index < additionalLightsCount; ++index)
                {
                    Light addLight = GetAdditionalLight(index, i.worldPosition);
					float3 addLightResult = AdditionalLighting(addLight, normalWS);

					float addLightSpec = 0;
					#if defined(_SMOOTHNESS_ON)
						half3 reflectDirection = reflect(-addLight.direction, normalWS);
		                half spec = saturate(dot(reflectDirection, i.viewDirection));
			            addLightSpec = pow(spec, _Smoothness);
					#endif
					
                    lighting += addLightResult + addLightSpec;
                }

            	float nl = clamp(dot(i.normal,normalize(_MainLightPosition.xyz)), 0.2, 1.0);
            	
				color = float4(color.rgb * nl * lighting, color.a);
            	color.rgb = MixFog(color.rgb, i.fogCoord.x);
            	
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
			ColorMask 0
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
            #pragma multi_compile_shadowcaster

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "URPAnimationInstancingBaseCustom.hlsl"

            struct v2f
            {
	            float4 vertex : SV_POSITION;
            };
            
            v2f vertn(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                vert(v);

            	float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
            	float3 normalWS = TransformObjectToWorldNormal(v.normal.xyz);
            	float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));

				o.vertex = positionCS;
            	
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                return 0;
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