# Stage 1: Base image with core dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1

# System dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    libgl1 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install comfy-cli and runpod
RUN pip install --no-cache-dir \
    comfy-cli==1.3.6 \
    runpod==1.3.6

# Install ComfyUI core
RUN /usr/bin/yes | comfy --workspace /comfyui install \
    --cuda-version 11.8 \
    --nvidia \
    --version 0.3.26

# Clone custom nodes with validation and retries
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/M1kep/ComfyLiterals || echo "Warning: Failed to clone ComfyLiterals" \
 && git clone https://github.com/tsogzark/ComfyUI-load-image-from-url \
 && git clone https://github.com/Jordach/comfy-plasma \
 && git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes \
 && git clone https://github.com/theUpsider/ComfyUI-Logic \
 && { git clone https://codeberg.org/Gourieff/comfyui-reactor-node.git || \
     git clone https://github.com/Gourieff/comfyui-reactor-node.git; } \
 && git clone https://github.com/chrisgoringe/cg-image-picker.git \
 && git clone https://github.com/ltdrdata/ComfyUI-Manager \
 && git clone https://github.com/cubiq/ComfyUI-InstantID \
 && git clone https://github.com/BlenderNeko/ComfyUI-Depth-Anything-V2 \
 && git clone https://github.com/BlenderNeko/ComfyUI_Inpaint-Nodes \
 && git clone https://github.com/Fannovel16/comfyui_controlnet_aux

# Install node requirements with error handling
RUN cd ComfyUI-InstantID && pip install -r requirements.txt \
 && cd ../ComfyUI-Depth-Anything-V2 && pip install -r requirements.txt \
 && cd ../comfyui_controlnet_aux && pip install -r requirements.txt \
 && cd ../comfyui-reactor-node && pip install -r requirements.txt

# Create model directories
RUN mkdir -p /comfyui/models/{checkpoints,controlnet,insightface,blip,vae}

# Add application files
WORKDIR /
COPY src/extra_model_paths.yaml /comfyui/
COPY src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Handle snapshots and websocket support
COPY *snapshot*.json ./
COPY websocket_image_save.py /comfyui/custom_nodes/

# Stage 2: Model downloader
FROM base as downloader
ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Download models with retries
RUN mkdir -p /comfyui/models/checkpoints /comfyui/models/vae && \
    if [ "$MODEL_TYPE" = "sdxl" ]; then \
    wget --tries=3 -O /comfyui/models/vae/sdxl_vae.safetensors \
    https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors && \
    wget --tries=3 -O /comfyui/models/vae/sdxl-vae-fp16-fix.safetensors \
    https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors; \
    fi

# Stage 3: Final image
FROM base as final

# Copy models and restore snapshot
COPY --from=downloader /comfyui/models /comfyui/models
RUN /restore_snapshot.sh

CMD ["/start.sh"]
