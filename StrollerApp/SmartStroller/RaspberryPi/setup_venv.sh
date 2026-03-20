#!/bin/bash
# Setup script for Python virtual environment
# Run with: bash setup_venv.sh

set -e

echo "=========================================="
echo "SmartStroller Python Environment Setup"
echo "=========================================="

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    echo "Install it with: sudo apt install python3 python3-venv"
    exit 1
fi

# Check if venv module is available
if ! python3 -m venv --help &> /dev/null; then
    echo "Error: python3-venv is not installed"
    echo "Install it with: sudo apt install python3-venv"
    exit 1
fi

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing requirements..."
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found, installing Flask directly..."
    pip install Flask
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "To activate the virtual environment, run:"
echo "  source venv/bin/activate"
echo ""
echo "Then run the server with:"
echo "  python3 raspberry_pi_server.py"
echo ""
echo "To deactivate the virtual environment:"
echo "  deactivate"
echo ""
