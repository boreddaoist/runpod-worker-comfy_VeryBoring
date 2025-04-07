# Stage 1: Base image with core dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    COMFYUI_PATH=/comfyui \
    CUSTOM_NODES_PATH=/comfyui/custom_nodes

# System dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    unzip \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install core Python packages
RUN pip install --no-cache-dir \
    comfy-cli==1.3.6 \
    torch==2.6.0 \
    torchvision==0.21.0 \
    torchaudio==2.6.0 \
    xformers==0.0.25

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace ${COMFYUI_PATH} install \
    --cuda-version 11.8 \
    --nvidia \
    --version 0.3.26

# Clone custom nodes with version control
WORKDIR ${CUSTOM_NODES_PATH}
RUN git clone https://github.com/Gourieff/comfyui-reactor-node.git \
    && git clone https://github.com/cubiq/ComfyUI-InstantID.git \
    && git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    && git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    && git clone https://github.com/theUpsider/ComfyUI-Logic.git \
    && git clone https://github.com/BlenderNeko/ComfyUI-Depth-Anything-V2.git \
    && git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    && git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    && git clone https://github.com/BlenderNeko/ComfyUI_Inpaint-Nodes.git \
    && git clone https://github.com/WASasquatch/was-node-suite-comfyui.git

# Checkout specific versions for compatibility
RUN cd ComfyUI-Depth-Anything-V2 && git checkout 4c5cc4d \
    && cd ../comfyui_controlnet_aux && git checkout v1.0.7

# Install Python dependencies for nodes
RUN pip install --no-cache-dir \
    insightface==0.7.3 \
    onnxruntime-gpu==1.16.3 \
    opencv-python-headless==4.9.0.80 \
    mediapipe==0.10.21 \
    rembg==2.0.62 \
    timm==1.0.14 \
    transformers==4.48.3

# Install node-specific requirements
RUN cd comfyui-reactor-node && pip install -r requirements.txt \
    && cd ../ComfyUI-InstantID && pip install -r requirements.txt \
    && cd ../ComfyUI-Depth-Anything-V2 && pip install -r requirements.txt

# Create empty model directory structure
RUN mkdir -p ${COMFYUI_PATH}/models/{checkpoints,controlnet,insightface,blip}

# Copy application files
WORKDIR /
COPY src/start.sh src/restore_snapshot.sh src/rp_handler.py ./
COPY *snapshot*.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Stage 2: Prepare model structure
FROM base as downloader

# Create empty directory structure
RUN mkdir -p ${COMFYUI_PATH}/models/checkpoints

# Stage 3: Final image
FROM base as final
COPY --from=downloader ${COMFYUI_PATH}/models ${COMFYUI_PATH}/models

# Entrypoint configuration
CMD ["/start.sh"]
