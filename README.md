VERL Setup Script (tested on Ubuntu)
Automated installation script for VERL (Volcano Engine Reinforcement Learning) environment on Ubuntu 22.04
What it does:

- Installs CUDA 12.4 and cuDNN 9.8.0 (if not present or older versions detected)
- Sets up UV package manager and creates Python virtual environment using system Python version.
- Installs VERL framework with vLLM integration and NVIDIA Apex for optimized training
- Configures Jupyter notebook for remote access on port 5000 and launches Jupyter in tmux session for persistent remote development

Key Components Installed:

CUDA Toolkit 12.4.1
cuDNN 9.8.0
VERL (latest from GitHub)
vLLM 0.10.2
NVIDIA Apex (with CUDA extensions)
Jupyter Notebook (port 5000)

Output:
Displays all version information and provides SSH tunnel command for remote Jupyter access link with token

You might need to re-ssh to the server to detect UV.
