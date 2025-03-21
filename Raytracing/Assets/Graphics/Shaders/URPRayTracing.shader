Shader "Unlit/URPRayTracing"
{
    Properties
    {
        _MainTex("Example Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags{
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
            }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _TestColor;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            struct a2v
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float4 color : COLOR;
            };

            struct Ray
            {
                float3 origin;
                float3 dir;
            };

            struct RayTracingMaterial
            {
                float4 color;
                float4 emissionColor;
                float emissionStrength;
                float roughness;
            };

            struct Sphere
            {
                float3 position;
                float radius;
                RayTracingMaterial material;
            };

            float3 ViewParams;
            float4x4 CamLocalToWorldMatrix;
            StructuredBuffer<Sphere> RayTracingSpheres;
            int NumSpheres;
            int NumPaysPerPixel;
            int MaxBounceCount;

            struct RayTracingHitInfo
            {
                bool didHit;
                float dst;
                float3 hitPoint;
                float3 normal;
                RayTracingMaterial material;
            };

            RayTracingHitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius)
            {
                RayTracingHitInfo hitInfo = (RayTracingHitInfo)0;
                float3 offsetRayOrigin = ray.origin - sphereCenter;
                // From the equation: sgrLength(rayOrigin + rayDir * dst) = radius'2
                // Solving for dst results in a quadratic equation with coefficients:
                float a = dot(ray.dir, ray.dir); // a = 1 (assuming unit vector)
                float b = 2 * dot(offsetRayOrigin, ray.dir);
                float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
                // Quadratic discriminant
                float discriminant = b * b - 4 * a * c;
                // No solution when d < 0 (ray misses sphere)
                if (discriminant >= 0)
                {
                    // Distance to nearest intersection point (from quadratic formula)
                    float dst = (-b - sqrt(discriminant)) / (2 * a);
                    // Ignore intersections that occur behind the ray
                    if (dst >= 0)
                    {
                        hitInfo.didHit = true;
                        hitInfo.dst = dst;
                        hitInfo.hitPoint = ray.origin + ray.dir * dst;
                        hitInfo.normal = normalize(hitInfo.hitPoint - sphereCenter);
                    }
                }
                return hitInfo;
            }

            // Find the first point that the given ray collides with, and return hit info
            RayTracingHitInfo CaculateRayCollision(Ray ray)
            {
                RayTracingHitInfo closestHit = (RayTracingHitInfo)0;
                // We haven't hit anything yet, so 'closest' hit is infinitely far away
                closestHit.dst = 1.#INF;
                // Raycast against all spheres and keep info about the closest hit
                for (int i = 0; i < NumSpheres; i ++)
                {
                    Sphere sphere = RayTracingSpheres[i];
                    RayTracingHitInfo hitInfo = RaySphere(ray,sphere.position, sphere.radius);

                    if (hitInfo.didHit && hitInfo.dst < closestHit.dst)
                    {
                        closestHit = hitInfo;
                        closestHit.material = sphere.material;
                    }
                }
                return closestHit;
            }

            uint PixelIndex(v2f i)
            {
                uint2 numPixels = _ScreenParams.xy;
                uint2 pixelCoord = i.uv * numPixels;
                uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
                return pixelIndex;
            }

            float RandomValue(inout uint state)
            {
                state = state * 747796405 + 2891336453;
                uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
                result = (result >> 22) ^ result;
                return result / 4294967295.0;
            }

            float RandomValueNormalDistribution(inout uint state)
            {
                //https://stackoverflow.com/a/6178290
                float theta = 2 * 3.1415926535 * RandomValue(state);
                float rho = sqrt(-2 * log(RandomValue(state)));
                return rho * cos(theta);
            }

            float3 RandomDirection(inout uint state)
            {
                float x = RandomValueNormalDistribution(state);
                float y = RandomValueNormalDistribution(state);
                float z = RandomValueNormalDistribution(state);
                return normalize(float3(x,y,z));
            }

            float3 RandomHemisphereDirection(float3 normal, inout uint rngState)
            {
                float3 dir = RandomDirection(rngState);
                return dir * sign(dot(normal,dir));
            }

            float3 ImportanceHemisphereDirection(float3 normal, inout uint rngState)
            {
                return normalize(normal + RandomDirection(rngState));
            }

            float3 MirrorRayDir(Ray ray , float3 normal)
            {
                float3 dir = reflect(ray.dir ,normal);
                return dir;
            }

            float3 ReflectRayDir(Ray ray, RayTracingHitInfo hitInfo , inout uint rngState)
            {
                float3 hemisphereDir = ImportanceHemisphereDirection(hitInfo.normal,rngState);
                float3 mirrorDir = MirrorRayDir(ray , hitInfo.normal);
                return lerp(mirrorDir,hemisphereDir,hitInfo.material.roughness);
            }

            //Trace path of light (in reverse) travels from camera
            //reflect off objects in the scene , and maybe ends up at light source
            float3 Trace(Ray ray, inout uint rngState)
            {
                float3 incomingLight = 0;
                float3 rayColor = 1;
                for (int i = 0; i < MaxBounceCount; i++)
                {
                    RayTracingHitInfo hitInfo = CaculateRayCollision(ray);
                    if (hitInfo.didHit)
                    {
                        ray.origin = hitInfo.hitPoint;
                        ray.dir = ReflectRayDir(ray,hitInfo,rngState);

                        RayTracingMaterial material = hitInfo.material;
                        float3 emittedLight = material.emissionColor * material.emissionStrength;
                        incomingLight += rayColor * emittedLight;
                        rayColor *= material.color;
                    }
                    else
                    {
                        break;
                    }  
                }
                return incomingLight;
            }

            float3 MultiRayTrace(Ray ray , uint rngState)
            {
                float3 totalIncomingLight = 0;
                for (int rayIndex = 0; rayIndex < NumPaysPerPixel; rayIndex++)
                {
                    totalIncomingLight += Trace(ray,rngState);
                }
                float3 pixelCol = totalIncomingLight / NumPaysPerPixel;
                return pixelCol;
            }

            v2f vert(a2v v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color;

                float3 viewPointLocal = float3(v.uv - 0.5, 1) * ViewParams;
                float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));
                o.viewDir = viewPoint - _WorldSpaceCameraPos.xyz;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(i.viewDir);
                uint pixelIndex = PixelIndex(i);

                return float4(MultiRayTrace(ray,pixelIndex),1);
                return float4(normalize(i.viewDir), 1);
            }
            ENDHLSL
        }
    }
}
