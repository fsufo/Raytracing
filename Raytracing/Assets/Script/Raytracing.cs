using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// [ExecuteAlways, ImageEffectAllowedInSceneView]
[SerializeField,VolumeComponentMenuForRenderPipeline("Test/Raytracing",typeof(UniversalRenderPipeline))]
public class CustomRaytracing : VolumeComponent,IPostProcessComponent
{
    public IntParameter NumPaysPerPixel = new IntParameter(2);
    public IntParameter MaxBounceCount = new IntParameter(2);
    public bool IsActive() => true;
    public bool IsTileCompatible() => true;
}
