# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 AS base

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
    && pip install onnxruntime-gpu \
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
RUN mkdir -p models/checkpoints models/vae models/inpaint models/instantid models/instantid/SDXL models/upscale_models models/controlnet models/controlnet/SDXL models/controlnet/SDXL/controlnet-union-sdxl-1.0 models/controlnet/SDXL/instantid models/insightface models/insightface/models models/insightface/models/antelopev2


RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
  
    wget -O models/insightface/models/antelopev2/1k3d68.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/1k3d68.onnx && \
    wget -O models/insightface/models/antelopev2/2d106det.onnx https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/2d106det.onnx; \
    fi

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models
RUN mkdir -p comfyui/output

# Start container
CMD ["/start.sh"]
