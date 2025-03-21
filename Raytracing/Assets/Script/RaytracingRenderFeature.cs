//TODO fix it in Unity 6
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RaytracingRenderFeature : ScriptableRendererFeature
{
    private RaytracingPass raytracingPass;

    public override void Create()
    {
        // throw new System.NotImplementedException();
        raytracingPass = new RaytracingPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // throw new System.NotImplementedException();
        renderer.EnqueuePass(raytracingPass);
    }

    class RaytracingPass : ScriptableRenderPass
    {
        private Material _mat;
        // int raytracingID = Shader.PropertyToID("_Temp");
        RTHandle src , target;
        public RaytracingPass()
        {
            if (!_mat)
            {
                _mat = CoreUtils.CreateEngineMaterial("Unlit/URPRayTracing");
            }
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            src = renderingData.cameraData.renderer.cameraColorTargetHandle;
            // cmd.GetTemporaryRT(raytracingID , desc ,FilterMode.Bilinear);
            // target = new RenderTargetIdentifier(raytracingID);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer commandBuffer = CommandBufferPool.Get("RaytracingRenderFeature");
            //获取到 Rayracing Volume中的参数
            VolumeStack volumes = VolumeManager.instance.stack;
            //这边是拿到volume中Raytracing的数据
            CustomRaytracing crData = volumes.GetComponent<CustomRaytracing>();
            if (crData.IsActive())
            {
                Camera camera = renderingData.cameraData.camera;
                float PlaneHeight = camera.nearClipPlane * Mathf.Tan(camera.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
                float PlaneWidth = PlaneHeight * camera.aspect;
                _mat.SetVector("ViewParams",new Vector3(PlaneWidth,PlaneHeight,camera.nearClipPlane));
                _mat.SetMatrix("CamLocalToWorldMatrix",camera.transform.localToWorldMatrix);
                _mat.SetInt("NumPaysPerPixel",(int)crData.NumPaysPerPixel);
                _mat.SetInt("MaxBounceCount",(int)crData.MaxBounceCount);
                Blitter.BlitTexture(commandBuffer,src,target,_mat,0);
                Blit(commandBuffer,target,src);
            }
            context.ExecuteCommandBuffer(commandBuffer);
            CommandBufferPool.Release(commandBuffer);

            // throw new System.NotImplementedException();
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            // cmd.ReleaseTemporaryRT(raytracingID);
        }
    }
}
