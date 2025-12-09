"""
Terrain Tile Extractor - Auto-detect boundaries
Automatically detects exact tile boundaries by finding white background edges.

Usage:
    python extract_tiles_auto.py           # Extract tiles
    python extract_tiles_auto.py --preview # Generate preview showing detected boundaries
    python extract_tiles_auto.py --debug   # Show detailed detection info

Requires: Pillow (pip install Pillow)
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow not installed. Run: pip install Pillow")
    exit(1)


# Tile definitions (name, column, row)
IMAGE1_TILES = [
    ("asphalt", 0, 0), ("basalt", 1, 0), ("brick", 2, 0), ("cobblestone", 3, 0),
    ("concrete", 0, 1), ("crackedlava", 1, 1), ("glacier", 2, 1), ("grass", 3, 1),
    ("ground", 0, 2), ("ice", 1, 2), ("leafygrass", 2, 2), ("limestone", 3, 2),
]

IMAGE2_TILES = [
    ("mud", 0, 0), ("pavement", 1, 0), ("rock", 2, 0), ("salt", 3, 0),
    ("sand", 0, 1), ("sandstone", 1, 1), ("slate", 2, 1), ("snow", 3, 1),
    ("water", 0, 2), ("woodplanks", 1, 2), ("air", 2, 2),
]


def is_background(pixel: tuple, threshold: int = 245) -> bool:
    """
    Check if a pixel is part of the white background.
    The background is white (#FFFFFF) or very close to it.
    """
    if len(pixel) == 4:  # RGBA
        r, g, b, a = pixel
        if a < 128:  # Transparent
            return True
    else:  # RGB
        r, g, b = pixel[:3]
    
    # Check if all channels are above threshold (near-white)
    return r >= threshold and g >= threshold and b >= threshold


def find_edge(img: Image.Image, start_x: int, start_y: int, dx: int, dy: int, 
              max_steps: int = 500, threshold: int = 245) -> tuple[int, int]:
    """
    Walk from start position in direction (dx, dy) until we hit background.
    Returns the last non-background pixel position.
    """
    x, y = start_x, start_y
    width, height = img.size
    
    for _ in range(max_steps):
        next_x = x + dx
        next_y = y + dy
        
        # Check bounds
        if next_x < 0 or next_x >= width or next_y < 0 or next_y >= height:
            break
        
        pixel = img.getpixel((next_x, next_y))
        if is_background(pixel, threshold):
            break
        
        x, y = next_x, next_y
    
    return x, y


def detect_tile_bounds(img: Image.Image, approx_center_x: int, approx_center_y: int,
                       threshold: int = 245, debug: bool = False) -> tuple[int, int, int, int]:
    """
    Detect the exact bounds of a tile by walking outward from an approximate center.
    Returns (left, top, right, bottom) pixel coordinates.
    """
    # First, make sure we're actually inside a tile (not on background)
    center_pixel = img.getpixel((approx_center_x, approx_center_y))
    if is_background(center_pixel, threshold):
        # Try to find the actual tile by searching nearby
        found = False
        for offset in range(1, 50):
            for dx, dy in [(0, 0), (offset, 0), (-offset, 0), (0, offset), (0, -offset),
                          (offset, offset), (-offset, -offset), (offset, -offset), (-offset, offset)]:
                test_x = approx_center_x + dx
                test_y = approx_center_y + dy
                if 0 <= test_x < img.size[0] and 0 <= test_y < img.size[1]:
                    if not is_background(img.getpixel((test_x, test_y)), threshold):
                        approx_center_x = test_x
                        approx_center_y = test_y
                        found = True
                        break
            if found:
                break
        
        if not found:
            if debug:
                print(f"    WARNING: Could not find tile at ({approx_center_x}, {approx_center_y})")
            return None
    
    # Walk in all 4 directions to find edges
    _, top = find_edge(img, approx_center_x, approx_center_y, 0, -1, threshold=threshold)  # Up
    _, bottom = find_edge(img, approx_center_x, approx_center_y, 0, 1, threshold=threshold)  # Down
    left, _ = find_edge(img, approx_center_x, approx_center_y, -1, 0, threshold=threshold)  # Left
    right, _ = find_edge(img, approx_center_x, approx_center_y, 1, 0, threshold=threshold)  # Right
    
    # Also check corners to ensure we have the full extent
    # Sometimes walking straight doesn't capture corner pixels
    _, corner_top = find_edge(img, left, approx_center_y, 0, -1, threshold=threshold)
    _, corner_bottom = find_edge(img, left, approx_center_y, 0, 1, threshold=threshold)
    corner_left, _ = find_edge(img, approx_center_x, top, -1, 0, threshold=threshold)
    corner_right, _ = find_edge(img, approx_center_x, top, 1, 0, threshold=threshold)
    
    # Use the most extreme values
    top = min(top, corner_top)
    bottom = max(bottom, corner_bottom)
    left = min(left, corner_left)
    right = max(right, corner_right)
    
    if debug:
        print(f"    Detected bounds: ({left}, {top}) to ({right}, {bottom})")
        print(f"    Size: {right - left + 1} x {bottom - top + 1}")
    
    return left, top, right + 1, bottom + 1  # +1 because crop is exclusive on right/bottom


def get_approximate_centers(width: int, height: int, cols: int = 4, rows: int = 3) -> list[tuple[int, int]]:
    """
    Calculate approximate center positions for each tile in the grid.
    """
    # Rough margins (we don't need to be precise - just need to land inside each tile)
    left_margin = width * 0.03
    right_margin = width * 0.03
    top_margin = height * 0.03
    bottom_margin = height * 0.08  # More bottom margin for labels
    
    usable_width = width - left_margin - right_margin
    usable_height = height - top_margin - bottom_margin
    
    cell_width = usable_width / cols
    cell_height = usable_height / rows
    
    centers = []
    for row in range(rows):
        for col in range(cols):
            # Center of each cell, offset slightly up to avoid label text
            x = int(left_margin + (col + 0.5) * cell_width)
            y = int(top_margin + (row + 0.4) * cell_height)  # 0.4 instead of 0.5 to be above center
            centers.append((x, y))
    
    return centers


def detect_tile_size(img: Image.Image, tiles: list[tuple[str, int, int]], 
                     debug: bool = False) -> tuple[int, int]:
    """
    Detect the common tile size by sampling a few tiles and finding the mode.
    """
    width, height = img.size
    centers = get_approximate_centers(width, height)
    
    sizes = []
    for name, col, row in tiles[:6]:  # Sample first 6 tiles
        idx = row * 4 + col
        if idx < len(centers):
            cx, cy = centers[idx]
            bounds = detect_tile_bounds(img, cx, cy, debug=debug)
            if bounds:
                left, top, right, bottom = bounds
                tile_width = right - left
                tile_height = bottom - top
                sizes.append((tile_width, tile_height))
                if debug:
                    print(f"  {name}: {tile_width}x{tile_height}")
    
    if not sizes:
        return None, None
    
    # Find the most common size (mode)
    from collections import Counter
    width_counter = Counter(s[0] for s in sizes)
    height_counter = Counter(s[1] for s in sizes)
    
    common_width = width_counter.most_common(1)[0][0]
    common_height = height_counter.most_common(1)[0][0]
    
    return common_width, common_height


def process_image(image_path: Path, tiles: list[tuple[str, int, int]], 
                  output_dir: Path, debug: bool = False):
    """Process a single composite image and extract all tiles with auto-detection."""
    print(f"\nProcessing: {image_path.name}")
    
    if not image_path.exists():
        print(f"  ERROR: File not found: {image_path}")
        return
    
    img = Image.open(image_path).convert("RGB")
    width, height = img.size
    print(f"  Image size: {width}x{height}")
    
    # Detect common tile size first
    print("  Detecting tile size...")
    tile_width, tile_height = detect_tile_size(img, tiles, debug=debug)
    if tile_width is None:
        print("  ERROR: Could not detect tile size")
        return
    print(f"  Detected tile size: {tile_width}x{tile_height}")
    
    # Get approximate centers
    centers = get_approximate_centers(width, height)
    
    extracted = 0
    for name, col, row in tiles:
        idx = row * 4 + col
        if idx >= len(centers):
            print(f"  WARNING: No center for {name} at ({col}, {row})")
            continue
        
        cx, cy = centers[idx]
        bounds = detect_tile_bounds(img, cx, cy, debug=debug)
        
        if bounds is None:
            print(f"  WARNING: Could not detect bounds for {name}")
            continue
        
        left, top, right, bottom = bounds
        
        # Crop the tile
        tile = img.crop((left, top, right, bottom))
        
        # Save as PNG
        output_path = output_dir / f"{name}.png"
        tile.save(output_path, "PNG")
        print(f"  Extracted: {name}.png ({tile.size[0]}x{tile.size[1]}) at ({left},{top})")
        extracted += 1
    
    print(f"  Total extracted: {extracted}")


def generate_preview(image_path: Path, tiles: list[tuple[str, int, int]], 
                     output_path: Path, debug: bool = False):
    """Generate a preview image showing auto-detected boundaries."""
    print(f"\nGenerating preview for: {image_path.name}")
    
    if not image_path.exists():
        print(f"  ERROR: File not found: {image_path}")
        return
    
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    print(f"  Image size: {width}x{height}")
    
    # Create overlay for drawing
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    
    # Get approximate centers
    centers = get_approximate_centers(width, height)
    
    # Convert to RGB for detection (RGBA can cause issues)
    img_rgb = img.convert("RGB")
    
    for name, col, row in tiles:
        idx = row * 4 + col
        if idx >= len(centers):
            continue
        
        cx, cy = centers[idx]
        
        # Draw approximate center (yellow dot)
        draw.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(255, 255, 0, 200))
        
        # Detect bounds
        bounds = detect_tile_bounds(img_rgb, cx, cy, debug=debug)
        
        if bounds is None:
            # Draw red X for failed detection
            draw.line([cx-10, cy-10, cx+10, cy+10], fill=(255, 0, 0, 255), width=3)
            draw.line([cx-10, cy+10, cx+10, cy-10], fill=(255, 0, 0, 255), width=3)
            continue
        
        left, top, right, bottom = bounds
        
        # Draw detected rectangle (green)
        draw.rectangle([left, top, right-1, bottom-1], outline=(0, 255, 0, 255), width=2)
        
        # Draw corner markers (cyan)
        marker_size = 5
        for corner_x, corner_y in [(left, top), (right-1, top), (left, bottom-1), (right-1, bottom-1)]:
            draw.rectangle([corner_x-marker_size, corner_y-marker_size, 
                          corner_x+marker_size, corner_y+marker_size], 
                          fill=(0, 255, 255, 200))
        
        # Label
        draw.text((left + 5, top + 5), name, fill=(255, 255, 0, 255))
        
        if debug:
            print(f"  {name}: ({left},{top}) to ({right},{bottom}) = {right-left}x{bottom-top}")
    
    # Composite overlay onto image
    result = Image.alpha_composite(img, overlay)
    result.save(output_path, "PNG")
    print(f"  Saved preview: {output_path.name}")


def main():
    preview_mode = "--preview" in sys.argv or "-p" in sys.argv
    debug_mode = "--debug" in sys.argv or "-d" in sys.argv
    
    script_dir = Path(__file__).parent
    parent_dir = script_dir.parent
    output_dir = script_dir
    
    image1_path = parent_dir / "terrain-raw-asphalt-limestone.png"
    image2_path = parent_dir / "terrain-raw-mud-air.png"
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("=" * 60)
    if preview_mode:
        print("Terrain Tile Extractor - AUTO-DETECT PREVIEW MODE")
    else:
        print("Terrain Tile Extractor - AUTO-DETECT MODE")
    print("=" * 60)
    print(f"Output directory: {output_dir}")
    
    if preview_mode:
        generate_preview(image1_path, IMAGE1_TILES, output_dir / "preview-auto-1.png", debug=debug_mode)
        generate_preview(image2_path, IMAGE2_TILES, output_dir / "preview-auto-2.png", debug=debug_mode)
        
        print("\n" + "=" * 60)
        print("Preview generated!")
        print("Open preview-auto-1.png and preview-auto-2.png to verify detection.")
        print("")
        print("GREEN rectangles = auto-detected boundaries")
        print("YELLOW dots = approximate search centers")
        print("CYAN squares = detected corners")
        print("=" * 60)
    else:
        process_image(image1_path, IMAGE1_TILES, output_dir, debug=debug_mode)
        process_image(image2_path, IMAGE2_TILES, output_dir, debug=debug_mode)
        
        print("\n" + "=" * 60)
        print("Extraction complete!")
        print(f"Check {output_dir} for extracted tiles.")
        print("Open terrain-verification.html to verify the results.")
        print("=" * 60)


if __name__ == "__main__":
    main()



