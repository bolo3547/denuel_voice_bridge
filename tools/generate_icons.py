"""
Generate App Icons for Denuel Voice Bridge
==========================================
Creates modern, professional icons for the app.
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Installing Pillow...")
    os.system(f"{sys.executable} -m pip install Pillow")
    from PIL import Image, ImageDraw, ImageFont

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
PUBLIC_ICONS = PROJECT_ROOT / "public" / "icons"
ASSETS_DIR = PROJECT_ROOT / "app" / "mobile" / "denuel_voice_bridge" / "assets" / "images"

def create_icon(size, output_path, maskable=False):
    """Create a modern voice bridge icon."""
    # Create image with gradient background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Background colors - gradient effect (blue to purple)
    bg_color_1 = (102, 126, 234)  # #667EEA - blue
    bg_color_2 = (118, 75, 162)   # #764BA2 - purple
    
    # Calculate padding for maskable icons
    padding = size // 8 if maskable else 0
    
    # Draw background
    center = size // 2
    
    # Create gradient by blending colors
    for y in range(size):
        for x in range(size):
            # Check if point is within bounds
            if maskable:
                # Circular mask for maskable
                dist = ((x - center) ** 2 + (y - center) ** 2) ** 0.5
                if dist > (size // 2 - padding):
                    continue
            
            # Gradient based on position
            ratio = y / size
            r = int(bg_color_1[0] * (1 - ratio) + bg_color_2[0] * ratio)
            g = int(bg_color_1[1] * (1 - ratio) + bg_color_2[1] * ratio)
            b = int(bg_color_1[2] * (1 - ratio) + bg_color_2[2] * ratio)
            img.putpixel((x, y), (r, g, b, 255))
    
    # For non-maskable, create rounded rectangle mask
    if not maskable:
        radius = size // 5
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle([0, 0, size-1, size-1], radius=radius, fill=255)
        
        # Apply mask
        img.putalpha(mask)
    
    # Draw sound waves (voice symbol)
    draw = ImageDraw.Draw(img)
    wave_color = (255, 255, 255, 230)
    center_x = size // 2
    center_y = size // 2
    
    # Central circle (represents mouth/speaker)
    circle_radius = size // 10
    draw.ellipse([center_x - circle_radius, center_y - circle_radius,
                  center_x + circle_radius, center_y + circle_radius],
                 fill=wave_color)
    
    # Sound wave arcs
    line_width = max(2, size // 35)
    
    for i, scale in enumerate([0.22, 0.35, 0.48]):
        arc_radius = int(size * scale)
        bbox = [center_x - arc_radius, center_y - arc_radius,
                center_x + arc_radius, center_y + arc_radius]
        
        # Right arc
        draw.arc(bbox, start=-55, end=55, fill=wave_color, width=line_width)
        # Left arc  
        draw.arc(bbox, start=125, end=235, fill=wave_color, width=line_width)
    
    # Save
    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(output_path), 'PNG')
    print(f"✅ Created: {output_path.name} ({size}x{size})")

def main():
    print("🎨 Generating Denuel Voice Bridge Icons")
    print("=" * 40)
    
    # Web icons (public/icons/)
    PUBLIC_ICONS.mkdir(parents=True, exist_ok=True)
    
    create_icon(192, PUBLIC_ICONS / "Icon-192.png")
    create_icon(512, PUBLIC_ICONS / "Icon-512.png")
    create_icon(192, PUBLIC_ICONS / "Icon-maskable-192.png", maskable=True)
    create_icon(512, PUBLIC_ICONS / "Icon-maskable-512.png", maskable=True)
    
    # Favicon
    create_icon(32, PROJECT_ROOT / "public" / "favicon.png")
    
    # Mobile app icons
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    create_icon(1024, ASSETS_DIR / "app_icon.png")
    
    # Android sizes
    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    
    for density, size in android_sizes.items():
        create_icon(size, ASSETS_DIR / f"app_icon_{density}.png")
    
    # iOS sizes
    ios_sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]
    for size in ios_sizes:
        create_icon(size, ASSETS_DIR / f"app_icon_{size}.png")
    
    print()
    print("✅ All icons generated!")
    print(f"📁 Web icons: {PUBLIC_ICONS}")
    print(f"📁 Mobile icons: {ASSETS_DIR}")

if __name__ == "__main__":
    main()
