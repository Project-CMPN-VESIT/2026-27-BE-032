import subprocess
import time
import re
import os
import sys

CLOUDFLARED_PATH = r"C:\Program Files (x86)\cloudflared\cloudflared.exe"
FLUTTER_CONSTANTS_PATH = r"c:\Capstone Project\option2\DiabeticAI_Flutter\lib\utils\constants.dart"

def start_tunnel():
    print(f"🚀 Starting Cloudflare Tunnel using {CLOUDFLARED_PATH}...")
    
    # Launch cloudflared process
    proc = subprocess.Popen(
        [CLOUDFLARED_PATH, "tunnel", "--url", "http://localhost:8000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    
    tunnel_url = None
    
    # Read output line by line to extract the trycloudflare.com URL
    for line in proc.stdout:
        print(line, end="")
        match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
        if match:
            tunnel_url = match.group(0)
            print(f"\n==================================================")
            print(f"🎉 SUCCESS! Cloudflare Tunnel URL Captured:")
            print(f"    {tunnel_url}")
            print(f"==================================================\n")
            update_flutter_constants(tunnel_url)
            break

    # Keep process alive
    proc.wait()

def update_flutter_constants(url):
    if not os.path.exists(FLUTTER_CONSTANTS_PATH):
        print(f"⚠️ Flutter constants file not found at {FLUTTER_CONSTANTS_PATH}")
        return
        
    with open(FLUTTER_CONSTANTS_PATH, "r", encoding="utf-8") as f:
        content = f.read()
        
    # Replace baseUrl with new Cloudflare URL
    updated_content = re.sub(
        r'static const String baseUrl = ".*?";',
        f'static const String baseUrl = "{url}";',
        content
    )
    
    with open(FLUTTER_CONSTANTS_PATH, "w", encoding="utf-8") as f:
        f.write(updated_content)
        
    print(f"✅ Updated DiabeticAI_Flutter/lib/utils/constants.dart with baseUrl = \"{url}\"")

if __name__ == "__main__":
    start_tunnel()
