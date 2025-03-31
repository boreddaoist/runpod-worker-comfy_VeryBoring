# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1 
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install system dependencies with Reactor requirements
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
    libglib2.0-0 \
    libxrender1 \
    libxtst6 \
    && pip install \
        numba \
        mediapipe \
        onnxruntime-gpu==1.16.0 \  # CUDA 11.8 compatible version
        insightface==0.7.3 \
        opencv-python-headless==4.11.0.86 \
        comfyui-frontend-package \
        pykalman==0.10.1 \
        scipy==1.11.4 \
        imageio-ffmpeg \
        runpod \
        requests \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install comfy-cli and ComfyUI
RUN pip install comfy-cli && \
    /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.2.7

# Add configuration and scripts
WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./
WORKDIR /
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Add and restore snapshot
ADD *snapshot*.json /
RUN /restore_snapshot.sh

# Stage 2: Download models
FROM base AS downloader
ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

WORKDIR /comfyui
RUN mkdir -p models/checkpoints models/vae models/inpaint models/instantid models/instantid/SDXL \
    models/upscale_models models/controlnet models/controlnet/SDXL \
    models/controlnet/SDXL/controlnet-union-sdxl-1.0 models/controlnet/SDXL/instantid \
    models/insightface/models/antelopev2

RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
    wget -O models/inpaint/inpaint_v26.fooocus.patch \
        https://huggingface.co/lllyasviel/fooocus_inpaint/resolve/main/inpaint_v26.fooocus.patch && \
    wget -O models/inpaint/fooocus_inpaint_head.pth \
        https://huggingface.co/lllyasviel/fooocus_inpaint/resolve/main/fooocus_inpaint_head.pth && \
    wget -O models/checkpoints/zavychromaxl_v100.safetensors \
        https://huggingface.co/misri/zavychromaxl_v100/resolve/fe1c89f61d8f1c10ef1478993fad4f673dc45fbf/zavychromaxl_v100.safetensors; \
    fi

# Stage 3: Final image
FROM base AS final
COPY --from=downloader /comfyui/models /comfyui/models
RUN mkdir -p comfyui/output
CMD ["/start.sh"]
