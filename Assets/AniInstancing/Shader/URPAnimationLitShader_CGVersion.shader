// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/URPAnimationLitShader_TempSaveVersion"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Float) = 1
        [NoScaleOffset] _OcclusionMap("Occlusion", 2D) = "white" {}
        [NoScaleOffset] _SpecularMap("SpecularMap (RGB)", 2D) = "white" {}
        _SpecularScale("Specular Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			ZTest Less
			Cull Back
            
            CGPROGRAM
            //#pragma exclude_renderers gles gles3 glcore
			#pragma target 2.0

            #pragma vertex vertn
            #pragma fragment frag
            #pragma multi_compile_fog   // make fog work
            #pragma multi_compile_instancing
            #pragma multi_compile_forwardadd
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityLightingCommon.cginc"
            #include "URPAnimationInstancingBase.hlsl"

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPosition : TEXCOORD2;
                half3 N : TEXCOORD3;
                half3 T : TEXCOORD4;
                half3 B : TEXCOORD5;
                float3 lightDirection : TEXCOORD6;
                float3 viewDirection : TEXCOORD7;
                float3 vertexLighting : TEXCOORD11;
                float3 lightColor : COLOR;
                LIGHTING_COORDS(8,9)
            };

            sampler2D _MainTex;
            sampler2D _OcclusionMap;
            sampler2D _NormalMap;
            sampler2D _SpecularMap;

            CBUFFER_START(UnityPerMaterial)
            
            float4 _MainTex_ST;
            fixed4 _Color;
            float _NormalScale;
            float _SpecularScale;

            CBUFFER_END
            
            v2f vertn (appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(v);
                vert(v);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPosition = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                o.lightDirection = -_WorldSpaceLightPos0.xyz;
                o.viewDirection = normalize(o.worldPosition.xyz - _WorldSpaceCameraPos.xyz);
                o.lightColor = _LightColor0;
                
                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);

                float3 binormal = cross(v.normal, v.tangent.xyz);
				float3 worldBinormal = mul((float3x3)unity_ObjectToWorld, binormal);

				o.N = normalize(wNormal);
				o.T = normalize(wTangent);
				o.B = normalize(worldBinormal);
                
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                float3 vertexLighting = float3(0.0, 0.0, 0.0);
                for (int index = 0; index < 4; index++)
                {  
                    float4 lightPosition = float4(unity_4LightPosX0[index], 
                    unity_4LightPosY0[index], 
                    unity_4LightPosZ0[index], 1.0);

                    float3 vertexToLightSource = lightPosition.xyz - o.worldPosition.xyz;    
                    float3 lightDirection = normalize(vertexToLightSource);
                    float squaredDistance = dot(vertexToLightSource, vertexToLightSource);
                    float attenuation = 1.0 / (1.0 + unity_4LightAtten0[index] * squaredDistance);
                    float3 normalDir = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                    float3 diffuseReflection = attenuation 
                    * unity_LightColor[index].rgb * _Color.rgb 
                    * max(0.0, dot(normalDir, lightDirection));
                    vertexLighting = vertexLighting + diffuseReflection;

                    vertexLighting += diffuseReflection;
                }
                o.vertexLighting = vertexLighting;
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 tangentNormal = tex2D(_NormalMap, i.uv);
                tangentNormal = normalize(tangentNormal * 2 - 1);

                float3x3 TBN = float3x3(normalize(i.T), normalize(i.B), normalize(i.N));
				TBN = transpose(TBN);

                float3 worldNormal = mul(TBN, tangentNormal) * _NormalScale;
                
                float4 baseColor = tex2D(_MainTex, i.uv) * _Color;

                float3 lightDirection;
                float attenuation;
                if (0.0 == _WorldSpaceLightPos0.w) // directional light?
                {
                    attenuation = 1.0; // no attenuation
                    lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                } 
                else // point or spot light
                {
                    float3 vertexToLightSource = 
                    _WorldSpaceLightPos0.xyz - i.worldPosition.xyz;
                    float distance = length(vertexToLightSource);
                    attenuation = 1.0 / distance; // linear attenuation 
                    lightDirection = normalize(vertexToLightSource);
                }
                
                float3 diffuse = saturate(dot(worldNormal, lightDirection) * 0.5 + 0.5);
                float shadow = SHADOW_ATTENUATION(i);
                diffuse = i.lightColor * _Color.rgb * diffuse * shadow * attenuation;
                
                
                float occlusion = tex2D(_OcclusionMap, i.uv).r;
                baseColor *= occlusion;
                
				float3 specular = 0;
				if (diffuse.x > 0) {
					float3 reflection = reflect(-lightDirection, worldNormal);
					float3 viewDir = normalize(i.viewDirection);

					specular = saturate(dot(reflection, -viewDir));
					specular = pow(specular, 20.0f);

					float4 specularIntensity = tex2D(_SpecularMap, i.uv) * _SpecularScale;
					specular *= i.lightColor * specularIntensity * attenuation;
				}

                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * _Color;

                // Apply Fog
                UNITY_APPLY_FOG(i.fogCoord, baseColor);

                float4 color = float4(ambient + diffuse + specular, baseColor.a);
                color.rgb *= SHADOW_ATTENUATION(i);
                
                return color;
            }
            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ForwardAdd" }
            LOD 200

            Blend One One
			ZWrite On
			Cull Back
            
            CGPROGRAM
            //#pragma exclude_renderers gles gles3 glcore
			#pragma target 2.0
            
            #pragma vertex vertn
            #pragma fragment frag
            #pragma multi_compile_fog   // make fog work
            #pragma multi_compile_instancing
            #pragma multi_compile_forwardadd
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityLightingCommon.cginc"
            #include "URPAnimationInstancingBase.hlsl"

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPosition : TEXCOORD2;
                half3 N : TEXCOORD3;
                half3 T : TEXCOORD4;
                half3 B : TEXCOORD5;
                float3 lightDirection : TEXCOORD6;
                float3 viewDirection : TEXCOORD7;
                float3 vertexLighting : TEXCOORD11;
                float3 lightColor : COLOR;
                LIGHTING_COORDS(8,9)
            };

            sampler2D _MainTex;
            sampler2D _OcclusionMap;
            sampler2D _NormalMap;
            sampler2D _SpecularMap;

            CBUFFER_START(UnityPerMaterial)
            
            float4 _MainTex_ST;
            fixed4 _Color;
            float _NormalScale;
            float _SpecularScale;

            CBUFFER_END

            v2f vertn (appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(v);
                vert(v);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPosition = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                o.lightDirection = -_WorldSpaceLightPos0.xyz;
                o.viewDirection = normalize(o.worldPosition.xyz - _WorldSpaceCameraPos.xyz);
                o.lightColor = _LightColor0;
                
                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);

                float3 binormal = cross(v.normal, v.tangent.xyz);
				float3 worldBinormal = mul((float3x3)unity_ObjectToWorld, binormal);

				o.N = normalize(wNormal);
				o.T = normalize(wTangent);
				o.B = normalize(worldBinormal);
                
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                float3 vertexLighting = float3(0.0, 0.0, 0.0);
                for (int index = 0; index < 4; index++)
                {  
                    float4 lightPosition = float4(unity_4LightPosX0[index], 
                    unity_4LightPosY0[index], 
                    unity_4LightPosZ0[index], 1.0);

                    float3 vertexToLightSource = lightPosition.xyz - o.worldPosition.xyz;    
                    float3 lightDirection = normalize(vertexToLightSource);
                    float squaredDistance = dot(vertexToLightSource, vertexToLightSource);
                    float attenuation = 1.0 / (1.0 + unity_4LightAtten0[index] * squaredDistance);
                    float3 normalDir = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                    float3 diffuseReflection = attenuation 
                    * unity_LightColor[index].rgb * _Color.rgb 
                    * max(0.0, dot(normalDir, lightDirection));
                    vertexLighting = vertexLighting + diffuseReflection;

                    vertexLighting += diffuseReflection;
                }
                o.vertexLighting = vertexLighting;
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 tangentNormal = tex2D(_NormalMap, i.uv);
                tangentNormal = normalize(tangentNormal * 2 - 1);

                float3x3 TBN = float3x3(normalize(i.T), normalize(i.B), normalize(i.N));
				TBN = transpose(TBN);

                float3 worldNormal = mul(TBN, tangentNormal) * _NormalScale;
                
                float4 baseColor = tex2D(_MainTex, i.uv) * _Color;

                float3 lightDirection;
                float attenuation;
                if (_WorldSpaceLightPos0.w == 0.0) // directional light?
                {
                    attenuation = 1.0; // no attenuation
                    lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                } 
                else // point or spot light
                {
                    float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - i.worldPosition.xyz;
                    float distance = length(vertexToLightSource);
                    attenuation = 1.0 / distance; // linear attenuation 
                    lightDirection = normalize(vertexToLightSource);
                }
                
                float3 diffuse = saturate(dot(worldNormal, lightDirection) * 0.5 + 0.5);
                float shadow = SHADOW_ATTENUATION(i);
                diffuse = i.lightColor * _Color.rgb * diffuse * shadow * attenuation;
                
                
                float occlusion = tex2D(_OcclusionMap, i.uv).r;
                baseColor *= occlusion;
                
				float3 specular = 0;
				if (diffuse.x > 0) {
					float3 reflection = reflect(-lightDirection, worldNormal);
					float3 viewDir = normalize(i.viewDirection);

					specular = saturate(dot(reflection, -viewDir));
					specular = pow(specular, 20.0f);

					float4 specularIntensity = tex2D(_SpecularMap, i.uv) * _SpecularScale;
					specular *= i.lightColor * specularIntensity * attenuation;
				}

                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * _Color;

                // Apply Fog
                UNITY_APPLY_FOG(i.fogCoord, baseColor);

                float4 color = float4(ambient + diffuse + specular, baseColor.a);
                color.rgb *= SHADOW_ATTENUATION(i);
                
                return color;
            }
            ENDCG
        }

        Pass
        {
            Tags{"LightMode" = "ShadowCaster"}

            CGPROGRAM

            #pragma vertex vertn
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_shadowcaster

            #include "UnityCG.cginc"
            #include "URPAnimationInstancingBase.hlsl"

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

            ENDCG
        }
    }
}