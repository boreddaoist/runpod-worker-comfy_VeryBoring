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

# Install core packages from original requirements.txt
RUN pip install --no-cache-dir \
    comfy-cli==1.3.6 \
    runpod==1.3.6

# Install ComfyUI (original version from repo)
RUN /usr/bin/yes | comfy --workspace /comfyui install \
    --cuda-version 11.8 \
    --nvidia \
    --version 0.3.26

# Clone custom nodes from original docker-bake.hcl
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/M1kep/ComfyLiterals \
 && git clone https://github.com/tsogzark/ComfyUI-load-image-from-url \
 && git clone https://github.com/Jordach/comfy-plasma \
 && git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes \
 && git clone https://github.com/theUpsider/ComfyUI-Logic \
 && git clone https://codeberg.org/Gourieff/comfyui-reactor-node.git \
 && git clone https://github.com/chrisgoringe/cg-image-picker.git

# Add files from original repository structure
WORKDIR /
COPY src/start.sh src/restore_snapshot.sh src/rp_handler.py ./
COPY src/extra_model_paths.yaml /comfyui/
COPY test_input.json ./

# Original snapshot handling pattern
COPY *snapshot*.json ./

# Stage 2: Model downloader (original logic)
FROM base as downloader
ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Create model directories (matches original)
RUN mkdir -p /comfyui/models/checkpoints /comfyui/models/vae

# Original model download conditional
RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
    wget -O /comfyui/models/vae/sdxl_vae.safetensors \
    https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors && \
    wget -O /comfyui/models/vae/sdxl-vae-fp16-fix.safetensors \
    https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors; \
    fi

# Stage 3: Final image
FROM base as final

# Copy models from downloader
COPY --from=downloader /comfyui/models /comfyui/models

# Original snapshot restoration process
RUN /restore_snapshot.sh

# Original start command
CMD ["/start.sh"]
