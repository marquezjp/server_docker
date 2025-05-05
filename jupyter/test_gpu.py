import os
import sys
import subprocess

def check_nvidia_smi():
    print("=== Verificando nvidia-smi ===")
    try:
        result = subprocess.run(['nvidia-smi'], stdout=subprocess.PIPE, text=True)
        print(result.stdout)
    except Exception as e:
        print(f"Erro ao executar nvidia-smi: {e}")

def check_cuda_installation():
    print("\n=== Verificando instalação CUDA ===")
    cuda_path = os.environ.get('CUDA_HOME', '/usr/local/cuda')
    if os.path.exists(cuda_path):
        print(f"CUDA instalado em: {cuda_path}")
        
        # Verificar versão do CUDA
        try:
            nvcc_output = subprocess.run([f"{cuda_path}/bin/nvcc", "--version"], 
                                         stdout=subprocess.PIPE, text=True)
            print(nvcc_output.stdout)
        except Exception as e:
            print(f"CUDA encontrado, mas nvcc não pôde ser executado: {e}")
    else:
        print(f"CUDA não encontrado em {cuda_path}")
    
    print(f"Variável LD_LIBRARY_PATH: {os.environ.get('LD_LIBRARY_PATH', 'não definida')}")

def check_pytorch():
    print("\n=== Verificando PyTorch ===")
    try:
        import torch
        print(f"PyTorch versão: {torch.__version__}")
        print(f"CUDA disponível: {torch.cuda.is_available()}")
        
        if torch.cuda.is_available():
            print(f"Dispositivo atual: {torch.cuda.get_device_name(0)}")
            print(f"Número de GPUs: {torch.cuda.device_count()}")
            
            # Teste simples com PyTorch
            try:
                x = torch.tensor([1.0, 2.0, 3.0], device='cuda')
                y = torch.tensor([4.0, 5.0, 6.0], device='cuda')
                z = x + y
                print(f"Teste PyTorch: {x} + {y} = {z}")
            except Exception as e:
                print(f"Erro no teste PyTorch: {e}")
        else:
            print("Aviso: PyTorch não detectou nenhuma GPU disponível!")
    except ImportError:
        print("PyTorch não está instalado")

def check_tensorflow():
    print("\n=== Verificando TensorFlow ===")
    try:
        import tensorflow as tf
        print(f"TensorFlow versão: {tf.__version__}")
        
        # Verificar GPUs disponíveis
        gpus = tf.config.list_physical_devices('GPU')
        print(f"GPUs disponíveis: {gpus}")
        
        if gpus:
            # Teste simples com TensorFlow
            try:
                with tf.device('/GPU:0'):
                    a = tf.constant([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
                    b = tf.constant([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
                    c = tf.matmul(a, b)
                    print(f"Teste TensorFlow: Multiplicação de matriz concluída na GPU")
                    print(c)
            except Exception as e:
                print(f"Erro no teste TensorFlow: {e}")
                
            # Informações da GPU
            for gpu in gpus:
                print(f"Nome: {gpu.name}, Tipo: {gpu.device_type}")
        else:
            print("Aviso: TensorFlow não detectou nenhuma GPU disponível!")
    except ImportError:
        print("TensorFlow não está instalado ou é incompatível com esta versão do Python")
        print("Nota: TensorFlow 2.15 requer Python 3.9-3.11, não suporta Python 3.12")

def check_cupy():
    print("\n=== Verificando CuPy ===")
    try:
        import cupy as cp
        print(f"CuPy versão: {cp.__version__}")
        
        # Verificar informações da GPU
        try:
            print(f"Número de GPUs: {cp.cuda.runtime.getDeviceCount()}")
            for i in range(cp.cuda.runtime.getDeviceCount()):
                print(f"GPU {i}: {cp.cuda.runtime.getDeviceProperties(i)['name'].decode()}")
            
            # Teste simples com CuPy
            x_cp = cp.array([1, 2, 3])
            y_cp = cp.array([4, 5, 6])
            z_cp = x_cp + y_cp
            print(f"Teste CuPy: {x_cp} + {y_cp} = {z_cp}")
        except Exception as e:
            print(f"Erro no teste CuPy: {e}")
    except ImportError:
        print("CuPy não está instalado")

if __name__ == "__main__":
    print("===== DIAGNÓSTICO DE GPU NO JUPYTER CONTAINER =====")
    print(f"Python versão: {sys.version}")
    
    check_nvidia_smi()
    check_cuda_installation()
    check_pytorch()
    check_tensorflow()
    check_cupy()
    
    print("\n===== DIAGNÓSTICO COMPLETO =====")
    print("Se não houver erros acima e as GPUs forem detectadas, o ambiente está configurado corretamente.")
