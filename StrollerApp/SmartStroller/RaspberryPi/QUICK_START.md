# Quick Start Guide - Raspberry Pi Setup

Follow these steps to get your SmartStroller server running quickly.

## Step 1: Set Up Python Virtual Environment

Run this command to create and set up the virtual environment:

```bash
bash setup_venv.sh
```

Or manually:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Step 2: Set Up Access Point

Run the AP setup script:

```bash
chmod +x setup_ap.sh
sudo bash setup_ap.sh
```

## Step 3: Run the Server

**Important:** Always activate the virtual environment first:

```bash
source venv/bin/activate
python3 raspberry_pi_server.py
```

## Quick Commands Reference

```bash
# Activate virtual environment
source venv/bin/activate

# Run server
python3 raspberry_pi_server.py

# Deactivate virtual environment (when done)
deactivate
```

## Troubleshooting

### If you see "externally-managed-environment" error:
- Use the virtual environment (Step 1 above)
- Or install Flask via apt: `sudo apt install python3-flask`

### If virtual environment setup fails:
```bash
sudo apt install python3-venv
python3 -m venv venv
source venv/bin/activate
pip install Flask
```
