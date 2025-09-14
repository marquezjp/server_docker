FROM ollama/ollama

# Baixa o modelo DeepSeek-Coder 33B
RUN ollama pull deepseek-coder:33b

# Cria versão quantizada para 12 GB de VRAM
RUN echo -e "FROM deepseek-coder:33b\nPARAMETER quantization=q4_0" > /Modelfile && \
    ollama create deepseek-coder-q4 -f /Modelfile
