# Single stage build for SDXL
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install system dependencies (ADD THESE 3 LINES)
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
    libglib2.0-0 \      # Required for OpenCV
    libxrender1 \       # Required for face processing
    libxtst6 \          # Required for insightface
    && pip install comfy-cli runpod requests \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install ComfyUI
WORKDIR /comfyui
RUN /usr/bin/yes | comfy install --cuda-version 11.8 --nvidia --version 0.2.7

# Install Reactor dependencies (ADD THIS BLOCK)
RUN pip install \
    insightface==0.7.3 \
    onnxruntime-gpu==1.17.0 \
    opencv-python-headless==4.11.0.86 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# Add project files
ADD src/extra_model_paths.yaml ./
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json /
RUN chmod +x /start.sh /restore_snapshot.sh

# Install models
ARG MODEL_TYPE
RUN mkdir -p models/checkpoints models/vae models/inpaint
RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
    wget -O models/checkpoints/sd_xl_base_1.0.safetensors \
    https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors && \
    wget -O models/vae/sdxl_vae.safetensors \
    https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors; \
    fi

# Final setup
WORKDIR /
CMD ["/start.sh"]
