# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

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
    libgl1 \
    cmake \
    ffmpeg \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

RUN pip install \
    albumentations>=1.4.16 \
    onnx>=1.14.0 \
    opencv-python>=4.7.0.72 \
    numpy==1.26.3 \
    segment_anything \
    ultralytics \
    fairscale>=0.4.4 \
    gitpython \
    imageio \
    joblib \
    matplotlib \
    numba \
    opencv-python-headless[ffmpeg] \
    pilgram \
    rembg \
    scikit-image>=0.20.0 \
    scikit-learn \
    scipy \
    timm>=0.4.12 \
    tqdm \
    transformers

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.3.26

WORKDIR /comfyui

# Create and navigate to custom_nodes directory
RUN mkdir -p custom_nodes
WORKDIR /comfyui/custom_nodes

# Install custom nodes
RUN git clone https://github.com/M1kep/ComfyLiterals \
 && git clone https://github.com/Jordach/comfy-plasma \
 && git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes \
 && git clone https://github.com/chrisgoringe/cg-image-picker.git

# Go back to ComfyUI directory
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
FROM base as downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories
RUN mkdir -p models/checkpoints models/vae

# Download checkpoints/vae/LoRA to include in image based on model type
RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \ 
    wget -O models/vae/sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors && \
    wget -O models/vae/sdxl-vae-fp16-fix.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors; \ 
    fi

# Stage 3: Final image
FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models
COPY --from=downloader /comfyui/custom_nodes /comfyui/custom_nodes

# Start container
CMD ["/start.sh"]
