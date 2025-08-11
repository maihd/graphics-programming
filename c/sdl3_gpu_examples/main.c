#include <stdio.h>
#define SDL_MAIN_USE_CALLBACKS

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

static SDL_Window* window = NULL;
static SDL_GPUDevice* gpuDevice = NULL;

static SDL_GPUBuffer* vertexBuffer = NULL;
static SDL_GPUTransferBuffer* transferBuffer = NULL;

static SDL_GPUGraphicsPipeline* graphicsPipeline = NULL;

typedef struct Vertex
{
    float x, y, z;
    float r, g, b, a;
} Vertex;

// a list of vertices
static Vertex vertices[] = 
{
    {0.0f, 0.5f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f},     // top vertex
    {-0.5f, -0.5f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f},   // bottom left vertex
    {0.5f, -0.5f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f}     // bottom right vertex
};

typedef struct Uniform
{
    float time;
} Uniform;

SDL_AppResult SDL_AppInit(void** appstate, int argc, char* argv[])
{
    SDL_Log("Graphics Programming examples for SDL3 GPU (SDL3-Release-3.2.20)\n");

    // SDL_SetHint(SDL_HINT_RENDER_GPU_LOW_POWER, "1");
    // SDL_SetHint(SDL_HINT_RENDER_METAL_PREFER_LOW_POWER_DEVICE, "1");

    SDL_SetAppMetadata("SDL Hello World Example", "1.0", "com.example.sdl-hello-world");

    // Initialize windows and graphics device context

    if (!SDL_Init(SDL_INIT_VIDEO)) 
    {
        SDL_Log("SDL_Init(SDL_INIT_VIDEO) failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    window = SDL_CreateWindow("Hello SDL3 GPU", 640, 480, SDL_WINDOW_RESIZABLE);
    if (!window) 
    {
        SDL_Log("SDL_CreateWindowAndRenderer() failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    SDL_GPUShaderFormat shaderFlags = SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_MSL;
    gpuDevice = SDL_CreateGPUDevice(shaderFlags, true, NULL);
    SDL_ClaimWindowForGPUDevice(gpuDevice, window);
    if (!gpuDevice)
    {
        SDL_Log("SDL_CreateGPUDevice() failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    // Create buffers

    SDL_GPUBufferCreateInfo bufferInfo = {
        .size = sizeof(vertices),
        .usage = SDL_GPU_BUFFERUSAGE_VERTEX,
    };
    vertexBuffer = SDL_CreateGPUBuffer(gpuDevice, &bufferInfo);

    SDL_GPUTransferBufferCreateInfo transferBufferInfo = {
        .size = sizeof(vertices),
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD
    };
    transferBuffer = SDL_CreateGPUTransferBuffer(gpuDevice, &transferBufferInfo);

    Vertex* data = (Vertex*)SDL_MapGPUTransferBuffer(gpuDevice, transferBuffer, false);
    SDL_memcpy(data, vertices, sizeof(vertices));

    data[0] = vertices[0];
    data[1] = vertices[1];
    data[2] = vertices[2];

    SDL_UnmapGPUTransferBuffer(gpuDevice, transferBuffer);

    SDL_GPUCommandBuffer* commandBuffer = SDL_AcquireGPUCommandBuffer(gpuDevice);
    SDL_GPUCopyPass* copyPass = SDL_BeginGPUCopyPass(commandBuffer);

    SDL_GPUTransferBufferLocation location = {
        .transfer_buffer = transferBuffer,
        .offset = 0
    };
    SDL_GPUBufferRegion region = {
        .buffer = vertexBuffer,
        .size = sizeof(vertices),
        .offset = 0
    };

    SDL_UploadToGPUBuffer(copyPass, &location, &region, true);

    SDL_EndGPUCopyPass(copyPass);
    SDL_SubmitGPUCommandBuffer(commandBuffer);

    // Create shader and pipeline (like OpenGL Program)

    #if __APPLE__
    bool isMac = true;
    #define SHADER_EXT ".msl"
    #else
    bool isMac = false;
    #define SHADER_EXT ".spv"
    #endif

    size_t vertexCodeSize;
    void* vertexCode = SDL_LoadFile("../../shaders-out/triangle-vert" SHADER_EXT, &vertexCodeSize);

    SDL_GPUShaderCreateInfo vertexInfo = {
        .code = vertexCode,
        .code_size = vertexCodeSize,
        .entrypoint = isMac ? "main0" : "main",
        .format = isMac ? SDL_GPU_SHADERFORMAT_MSL : SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = SDL_GPU_SHADERSTAGE_VERTEX,
        .num_samplers = 0,
        .num_storage_buffers = 0,
        .num_storage_textures = 0,
        .num_uniform_buffers = 0,
    };
    SDL_GPUShader* vertexShader = SDL_CreateGPUShader(gpuDevice, &vertexInfo);
    if (!vertexShader)
    {
        SDL_Log("SDL_CreateGPUShader() VertexShader failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    SDL_free(vertexCode);

    size_t fragmentCodeSize;
    void* fragmentCode = SDL_LoadFile("../../shaders-out/triangle-frag" SHADER_EXT, &fragmentCodeSize);

    SDL_GPUShaderCreateInfo fragmentInfo = {
        .code = fragmentCode,
        .code_size = fragmentCodeSize,
        .entrypoint = isMac ? "main0" : "main",
        .format = isMac ? SDL_GPU_SHADERFORMAT_MSL : SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = SDL_GPU_SHADERSTAGE_FRAGMENT,
        .num_samplers = 0,
        .num_storage_buffers = 0,
        .num_storage_textures = 0,
        .num_uniform_buffers = 1,
    };
    SDL_GPUShader* fragmentShader = SDL_CreateGPUShader(gpuDevice, &fragmentInfo);
    if (!fragmentShader)
    {
        SDL_Log("SDL_CreateGPUShader() FragmentShader failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    SDL_free(fragmentCode);

    SDL_GPUVertexBufferDescription vertexBufferDescriptions[1] = {
        {
            .slot = 0,
            .input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX,
            .instance_step_rate = 0,
            .pitch = sizeof(Vertex)
        }  
    };

    SDL_GPUVertexAttribute vertexAttributes[2] = {
        {
            .buffer_slot = 0,
            .location = 0,
            .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .offset = 0,
        },

        {
            .buffer_slot = 0,
            .location = 1,
            .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
            .offset = sizeof(float) * 3,
        }
    };

    SDL_GPUColorTargetDescription colorTargetDescriptions[1] = {
        {
            .format = SDL_GetGPUSwapchainTextureFormat(gpuDevice, window)
        }
    };

    SDL_GPUGraphicsPipelineCreateInfo pipelineInfo = {
        .vertex_shader = vertexShader,
        .fragment_shader = fragmentShader,
        .primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        .vertex_input_state = {
            .num_vertex_buffers = 1,
            .vertex_buffer_descriptions = vertexBufferDescriptions,

            .num_vertex_attributes = 2,
            .vertex_attributes = vertexAttributes,
        },
        .target_info = {
            .num_color_targets = 1,
            .color_target_descriptions = colorTargetDescriptions
        }
    };

    graphicsPipeline = SDL_CreateGPUGraphicsPipeline(gpuDevice, &pipelineInfo);
    if (!graphicsPipeline) 
    {
        SDL_Log("SDL_CreateGPUGraphicsPipeline() failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }
    
    SDL_ReleaseGPUShader(gpuDevice, fragmentShader);
    SDL_ReleaseGPUShader(gpuDevice, vertexShader);

    return SDL_APP_CONTINUE;
}


void SDL_AppQuit(void *appstate, SDL_AppResult result)
{
    SDL_Log("SDL_AppQuit: cleaning all resources");

    SDL_ReleaseGPUGraphicsPipeline(gpuDevice, graphicsPipeline);

    SDL_ReleaseGPUTransferBuffer(gpuDevice, transferBuffer);
    SDL_ReleaseGPUBuffer(gpuDevice, vertexBuffer);

    SDL_DestroyGPUDevice(gpuDevice);
    SDL_DestroyWindow(window);
    SDL_Quit();
}


SDL_AppResult SDL_AppEvent(void *appstate, SDL_Event *event)
{
    switch (event->type) 
    {
        case SDL_EVENT_QUIT:  /* triggers on last window close and other things. End the program. */
            return SDL_APP_SUCCESS;

        case SDL_EVENT_KEY_DOWN:  /* quit if user hits ESC key */
            if (event->key.scancode == SDL_SCANCODE_ESCAPE) 
            {
                return SDL_APP_SUCCESS;
            }
            break;

        case SDL_EVENT_MOUSE_MOTION:  /* keep track of the latest mouse position */
            /* center the square where the mouse is */
            break;
    }

    return SDL_APP_CONTINUE;
}


SDL_AppResult SDL_AppIterate(void *appstate)
{
    SDL_GPUCommandBuffer* commandBuffer = SDL_AcquireGPUCommandBuffer(gpuDevice);

    Uint32 width, height;
    SDL_GPUTexture* swapchainTexture;
    SDL_WaitAndAcquireGPUSwapchainTexture(commandBuffer, window, &swapchainTexture, &width, &height);
    if (swapchainTexture == NULL)
    {
        SDL_SubmitGPUCommandBuffer(commandBuffer);
        return SDL_APP_CONTINUE;
    }

    SDL_GPUColorTargetInfo colorTargetInfo = {
        .clear_color = { 0.0f, 0.0f, 0.0f, 1.0f },
        .load_op = SDL_GPU_LOADOP_CLEAR,
        .store_op = SDL_GPU_STOREOP_STORE,
        .texture = swapchainTexture
    };

    SDL_GPURenderPass* renderPass = SDL_BeginGPURenderPass(commandBuffer, &colorTargetInfo, 1, NULL);
    if (renderPass == NULL)
    {
        SDL_SubmitGPUCommandBuffer(commandBuffer);
        return SDL_APP_CONTINUE;
    }

    SDL_BindGPUGraphicsPipeline(renderPass, graphicsPipeline);

    SDL_GPUBufferBinding bufferBindings[1] = {
        {
            .buffer = vertexBuffer,
            .offset = 0
        }
    };
    SDL_BindGPUVertexBuffers(renderPass, 0, bufferBindings, 1);

    Uniform uniform = { .time = SDL_GetTicksNS() / 1e9f };
    SDL_PushGPUFragmentUniformData(commandBuffer, 0, &uniform, sizeof(uniform));

    SDL_DrawGPUPrimitives(renderPass, 3, 1, 0, 0);

    SDL_EndGPURenderPass(renderPass);

    SDL_SubmitGPUCommandBuffer(commandBuffer);

    return SDL_APP_CONTINUE;
}

//! EOF
