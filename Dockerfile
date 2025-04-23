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
    opencv-python>=4.11.0.86 \
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
    insightface==0.7.3 \
    onnxruntime==1.20.1 \
    onnxruntime-gpu==1.20.1 \
    rembg \
    scikit-image>=0.20.0 \
    scikit-learn \
    scipy \
    timm>=0.4.12 \
    tqdm \
    pillow==11.1.0 \
    huggingface_hub \
    color-matcher \ 
    mss \
    accelerate \
    clip_interrogator>=0.6.0 \
    lark \
    sentencepiece \
    diffusers \
    spandrel \
    matplotlib \
    peft \
    git+https://github.com/WASasquatch/ffmpy.git \
    git+https://github.com/WASasquatch/img2texture.git \
    git+https://github.com/WASasquatch/cstr \ 
    transformers \
    torch \
    einops==0.8.1 \
    importlib_metadata \
    torchvision==0.21.0 \
    pyyaml \
    zipp \
    python-dateutil \
    mediapipe \
    svglib \
    fvcore \
    yapf \
    omegaconf \
    ftfy \
    addict \
    trimesh \    
    yacs \
    scikit-image \
    filelock==3.17.0 

    

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.3.26

WORKDIR /comfyui

# Create and navigate to custom_nodes directory
RUN mkdir -p custom_nodes
WORKDIR /comfyui/custom_nodes

# Install custom nodes
RUN git clone https://github.com/M1kep/ComfyLiterals \
 && git clone https://github.com/Jordach/comfy-plasma \
 && git clone https://github.com/cubiq/ComfyUI_InstantID \
 && git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes \
 && git clone https://github.com/chrisgoringe/cg-image-picker.git \
 && git clone https://codeberg.org/Gourieff/comfyui-reactor-node.git \
 && git clone https://github.com/chrisgoringe/cg-use-everywhere \
 && git clone https://github.com/Acly/comfyui-inpaint-nodes \
 && git clone https://github.com/kijai/ComfyUI-KJNodes \
 && git clone https://github.com/tsogzark/ComfyUI-load-image-from-url \
 && git clone https://github.com/theUpsider/ComfyUI-Logic \
 && git clone https://github.com/WASasquatch/was-node-suite-comfyui \
 && git clone https://github.com/yolain/ComfyUI-Easy-Use \
 && git clone https://github.com/Fannovel16/comfyui_controlnet_aux

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
RUN mkdir -p models/checkpoints models/inpaint models/vae models/instantid models/insightface models/facerestore_models models/insightface/models models/insightface/models/buffalo_l models/ultralytics models/ultralytics/bbox models/sams

# Download checkpoints/vae/LoRA to include in image based on model type

# Download models directly

RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
     wget -O models/insightface/inswapper_128.onnx https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx && \
     wget -O models/ultralytics/bbox/face_yolov8m.pt https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt && \
     wget -O models/sams/sam_vit_b_01ec64.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth && \
     wget -O models/insightface/models/buffalo_l/1k3d68.onnx https://huggingface.co/yolkailtd/face-swap-models/resolve/main/insightface/models/buffalo_l/1k3d68.onnx && \
     wget -O models/insightface/models/buffalo_l/2d106det.onnx https://huggingface.co/yolkailtd/face-swap-models/resolve/main/insightface/models/buffalo_l/2d106det.onnx && \
     wget -O models/insightface/models/buffalo_l/det_10g.onnx https://huggingface.co/yolkailtd/face-swap-models/resolve/main/insightface/models/buffalo_l/det_10g.onnx && \
     wget -O models/insightface/models/buffalo_l/genderage.onnx https://huggingface.co/yolkailtd/face-swap-models/resolve/main/insightface/models/buffalo_l/genderage.onnx && \
     wget -O models/insightface/models/buffalo_l/w600k_r50.onnx https://huggingface.co/yolkailtd/face-swap-models/resolve/main/insightface/models/buffalo_l/w600k_r50.onnx ;\
    fi


# Stage 3: Final image
FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Start container
CMD ["/start.sh"]
