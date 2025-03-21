using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using ComputeShaderUtility;
using UnityEngine.Rendering;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class RaytracingManager : MonoBehaviour
{
    public Material _material;

    GameObject[] _spheres;

    ComputeBuffer _rayTracingSpheresBuffer;

    void Start()
    {
        
    }

    void Update()
    {
        _spheres = GameObject.FindGameObjectsWithTag("RayTracingSphere");
        ComputeHelper.CreateStructuredBuffer<RayTracingSphere>(ref _rayTracingSpheresBuffer,_spheres.Length);
        RayTracingSphere[] rayTracingSpheres = new RayTracingSphere[_spheres.Length];
        for (int i = 0; i < rayTracingSpheres.Length; i++)
        {
            rayTracingSpheres[i] = new RayTracingSphere()
            {
                position = _spheres[i].transform.position,
                radius = (_spheres[i].transform.lossyScale * 0.5f).x,
                material = new RayTracingMaterial()
                    {
                        color = _spheres[i].GetComponent<RaytracintgSphere>().color,
                        emissionColor = _spheres[i].GetComponent<RaytracintgSphere>().emissionColor,
                        emissionStrength = _spheres[i].GetComponent<RaytracintgSphere>().emissionStrength,
                        roughness = _spheres[i].GetComponent<RaytracintgSphere>().roughness
                    }
            };
        }
        _rayTracingSpheresBuffer.SetData(rayTracingSpheres);
        Shader.SetGlobalBuffer("RayTracingSpheres",_rayTracingSpheresBuffer);
        Shader.SetGlobalInt("NumSpheres",_spheres.Length);
        // Debug.Log(rayTracingSpheres[0].radius);
    }

    private void OnDestroy() {
        _rayTracingSpheresBuffer.Release();
    }

    public struct RayTracingMaterial
    {
        public Color color;
        public Color emissionColor;
        public float emissionStrength;
        public float roughness;
    }

    public struct RayTracingSphere
    {
        public Vector3 position;
        public float radius;
        public RayTracingMaterial material;
    }
}
