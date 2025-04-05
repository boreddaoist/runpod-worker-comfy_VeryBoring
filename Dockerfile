# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 AS base

# Environment configurations
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    PYTHONHASHSEED=0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1 \
    liblapack-dev \
    libglib2.0-0 \
    libgomp1 \
    libopenblas-dev \
    libopenmpi-dev \
    libssl-dev \
    ninja-build \
    ccache \
    && rm -rf /var/lib/apt/lists/*

# Configure Python 3.10 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Install Python packages with pinned versions
RUN pip install --upgrade pip && \
    pip install \
    numba==0.61.0 \
    onnxruntime==1.20.0 \
    onnxruntime-gpu==1.20.0 \
    insightface==0.7.3 \
    comfyui-frontend-package==1.14.6 \
    pykalman==0.10.1 \
    scipy==1.11.4 \
    imageio-ffmpeg==0.6.0

# Install PyTorch with CUDA 12.1 support
RUN pip install torch==2.3.0 torchvision==0.18.0 torchaudio==2.3.0 \
    --index-url https://download.pytorch.org/whl/cu121

# Install comfy-cli and ComfyUI with correct CUDA version
RUN pip install comfy-cli && \
    /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 12.1 --nvidia --version 0.2.7

# Set up working directory
WORKDIR /comfyui

# Install RunPod SDK
RUN pip install runpod requests

# Add configuration and scripts
ADD src/extra_model_paths.yaml ./
WORKDIR /
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Handle snapshots
ADD *snapshot*.json /
RUN /restore_snapshot.sh

# Stage 2: Download models
FROM base AS downloader
ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

WORKDIR /comfyui
RUN mkdir -p models/{checkpoints,vae,inpaint,instantid/SDXL,upscale_models,controlnet/SDXL,insightface/models/antelopev2}

RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
    wget -O models/insightface/models/antelopev2/1k3d68.onnx \
        https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/1k3d68.onnx && \
    wget -O models/insightface/models/antelopev2/2d106det.onnx \
        https://huggingface.co/spaces/InstantX/InstantID/resolve/main/models/antelopev2/2d106det.onnx ; \
    fi

# Final stage
FROM base AS final
COPY --from=downloader /comfyui/models /comfyui/models
RUN mkdir -p comfyui/output

CMD ["/start.sh"]
