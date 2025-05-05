FROM quay.io/jupyter/datascience-notebook:python-3.11

USER root

# Instalar dependências básicas
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    gnupg2 \
    ca-certificates \
    libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verificar a versão do Python
RUN python --version

USER ${NB_UID}

# Instalação do PyTorch com suporte a CUDA
RUN pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Instalação do TensorFlow com GPU
RUN pip install --no-cache-dir tensorflow==2.15.0

# Instalação específica do CuPy
RUN pip install --no-cache-dir cupy-cuda12x

# Instalação de outras bibliotecas úteis para ciência de dados com GPU
RUN pip install --no-cache-dir \
    numba \
    opencv-python \
    scikit-learn \
    matplotlib \
    pandas \
    jupyterlab-nvdashboard

# Copiar o script de teste
COPY --chown=1000:100 test_gpu.py /home/jovyan/test_gpu.py

# Definir variáveis de ambiente para CUDA
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
