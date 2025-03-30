# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    ffmpeg \
    libsm6 \
    libxext6 \
    python3-opencv \
    libgl1 \
    liblapack-dev \
    libatlas-base-dev \
    gfortran \
    && pip install numba \
    && pip install mediapipe \
    && pip install onnxruntime \
    && pip install insightface \ 
    && pip install comfyui-frontend-package \
    && pip install pykalman==0.10.1 \
    && pip install scipy==1.11.4 \
    && pip install imageio-ffmpeg \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip
     
# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.2.7

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install runpod
RUN pip install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add scripts
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Optionally copy the snapshot file
ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories
RUN mkdir -p models/checkpoints models/vae models/inpaint models/instantid/SDXL models/upscale_models models/controlnet/SDXL/controlnet-union-sdxl-1.0 models/controlnet/SDXL/instantid models/insightface models/insightface/models/antelopev2


RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
    wget -O models/inpaint/inpaint_v26.fooocus.patch https://huggingface.co/lllyasviel/fooocus_inpaint/resolve/main/inpaint_v26.fooocus.patch && \
    wget -O models/inpaint/fooocus_inpaint_head.pth https://huggingface.co/lllyasviel/fooocus_inpaint/resolve/main/fooocus_inpaint_head.pth && \
    wget -O models/controlnet/SDXL/controlnet-union-sdxl-1.0/diffusion_pytorch_model_promax.safetensors https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors && \
    wget -O models/controlnet/SDXL/instantid/diffusion_pytorch_model.safetensors https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors && \
    wget -O models/instantid/SDXL/ip-adapter.bin https://huggingface.co/InstantX/InstantID/resolve/main/ip-adapter.bin && \
    wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth && \
    wget -O models/insightface/inswapper_128.onnx https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx && \
    wget -O models/insightface/models/antelopev2/1k3d68.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/1k3d68.onnx && \
    wget -O models/insightface/models/antelopev2/2d106det.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/2d106det.onnx && \
    wget -O models/insightface/models/antelopev2/genderage.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/genderage.onnx && \
    wget -O models/insightface/models/antelopev2/glintr100.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/glintr100.onnx && \
    wget -O models/insightface/models/antelopev2/scrfd_10g_bnkps.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/scrfd_10g_bnkps.onnx && \
    wget -O models/checkpoints/zavychromaxl_v100.safetensors https://huggingface.co/misri/zavychromaxl_v100/resolve/fe1c89f61d8f1c10ef1478993fad4f673dc45fbf/zavychromaxl_v100.safetensors; \
    
   fi

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models
RUN mkdir -p comfyui/output

# Start container
CMD ["/start.sh"]
