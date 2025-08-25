#!/usr/bin/env python3
"""
Create FileSure project structure and empty files
Run this script to create all the necessary directories and files
"""

import os
from pathlib import Path

def create_project_structure():
    """Create directories and empty files"""
    
    # Create directories
    directories = [
        'api',
        'worker',
        'k8s',
        'scripts',
        '.github/workflows'
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
    
    # Create all the new files (empty)
    files_to_create = [
        'api/Dockerfile',
        'worker/Dockerfile',
        'k8s/01-namespace-config.yaml',
        'k8s/02-mongodb.yaml',
        'k8s/03-api-service.yaml',
        'k8s/04-keda-scaledjob.yaml',
        'k8s/05-prometheus.yaml',
        'k8s/06-grafana.yaml',
        '.github/workflows/ci-cd.yml',
        'scripts/deploy.sh',
        'env.example',
        'docker-compose.dev.yml',
        'Makefile'
    ]
    
    for file_path in files_to_create:
        Path(file_path).touch()
        print(f"Created: {file_path}")
    
    # Make deploy.sh executable
    os.chmod('scripts/deploy.sh', 0o755)
    
    print(f"\nCreated {len(files_to_create)} files and {len(directories)} directories")
    print("You can now copy the specific code content into each file.")

if __name__ == "__main__":
    create_project_structure()