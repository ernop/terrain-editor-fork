"""
Terrain Tile Extractor
Extracts individual terrain texture tiles from composite screenshot images.

Usage:
    python extract_tiles.py           # Extract tiles
    python extract_tiles.py --preview # Generate preview showing crop boundaries

Requires: Pillow (pip install Pillow)
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow not installed. Run: pip install Pillow")
    exit(1)


# Grid configuration - adjust these if tiles don't align perfectly
# These values are estimated from the image layout

# Image 1: terrain-raw-asphalt-limestone.png (12 tiles in 4x3 grid)
IMAGE1_TILES = [
    # Row 1
    ("asphalt", 0, 0),
    ("basalt", 1, 0),
    ("brick", 2, 0),
    ("cobblestone", 3, 0),
    # Row 2
    ("concrete", 0, 1),
    ("crackedlava", 1, 1),
    ("glacier", 2, 1),
    ("grass", 3, 1),
    # Row 3
    ("ground", 0, 2),
    ("ice", 1, 2),
    ("leafygrass", 2, 2),
    ("limestone", 3, 2),
]

# Image 2: terrain-raw-mud-air.png (11 tiles in 4x3 grid, last cell empty)
IMAGE2_TILES = [
    # Row 1
    ("mud", 0, 0),
    ("pavement", 1, 0),
    ("rock", 2, 0),
    ("salt", 3, 0),
    # Row 2
    ("sand", 0, 1),
    ("sandstone", 1, 1),
    ("slate", 2, 1),
    ("snow", 3, 1),
    # Row 3
    ("water", 0, 2),
    ("woodplanks", 1, 2),
    ("air", 2, 2),
    # (3, 2) is empty
]


def detect_grid_bounds(img: Image.Image) -> tuple[int, int, int, int, int, int]:
    """
    Detect grid parameters from image dimensions.
    Returns: (left_margin, top_margin, tile_width, tile_height, gap_x, gap_y)
    """
    width, height = img.size
    
    # Approximate values based on typical Roblox docs screenshot layout
    # 4 columns, 3 rows
    # Tiles appear to be roughly square with some margin and gap
    
    # These are rough estimates - may need manual adjustment
    cols = 4
    rows = 3
    
    # Estimate based on image proportions
    # Assuming consistent margins and gaps
    left_margin = int(width * 0.025)  # ~2.5% margin
    top_margin = int(height * 0.02)   # ~2% top margin
    
    # Calculate available space for tiles
    available_width = width - (2 * left_margin)
    available_height = height - top_margin - int(height * 0.05)  # bottom has text labels
    
    # Gap between tiles (approximately)
    gap_x = int(available_width * 0.02)
    gap_y = int(available_height * 0.08)  # Larger gap for text labels
    
    # Tile dimensions
    tile_width = (available_width - (cols - 1) * gap_x) // cols
    tile_height = int(tile_width * 0.95)  # Slightly shorter due to labels taking space in row height
    
    return left_margin, top_margin, tile_width, tile_height, gap_x, gap_y


def extract_tile(img: Image.Image, col: int, row: int, 
                 left_margin: int, top_margin: int,
                 tile_width: int, tile_height: int,
                 cell_width: int, cell_height: int) -> Image.Image:
    """Extract a single tile from the grid."""
    x = left_margin + col * cell_width
    y = top_margin + row * cell_height
    
    # Crop the tile (just the image, not the label)
    return img.crop((x, y, x + tile_width, y + tile_height))


def get_grid_params(width: int, height: int) -> dict:
    """
    Calculate grid parameters for tile extraction.
    Adjust these values to fine-tune the crop boundaries.
    """
    cols = 4
    rows = 3
    
    # =================================================================
    # TUNING PARAMETERS - Adjust these to fix crop boundaries
    # =================================================================
    
    # Margins from image edge to first tile's top-left corner
    left_margin = 35
    top_margin = 26
    
    # Margins from last tile to image edge (used for cell size calculation)
    right_margin = 35
    bottom_margin = 40
    
    # How much of each cell is the actual tile (vs gap/label space)
    # Increase these to capture more pixels, decrease to capture fewer
    tile_width_ratio = 0.82   # 82% of cell width (increased to get right edge)
    tile_height_ratio = 0.78  # 78% of cell height (increased to get bottom edge)
    
    # =================================================================
    
    # Calculate cell size (tile + gap + label space)
    cell_width = (width - left_margin - right_margin) // cols
    cell_height = (height - top_margin - bottom_margin) // rows
    
    # Calculate tile size from ratios
    tile_width = int(cell_width * tile_width_ratio)
    tile_height = int(cell_height * tile_height_ratio)
    
    return {
        "cols": cols,
        "rows": rows,
        "left_margin": left_margin,
        "top_margin": top_margin,
        "cell_width": cell_width,
        "cell_height": cell_height,
        "tile_width": tile_width,
        "tile_height": tile_height,
    }


def generate_preview(image_path: Path, tiles: list[tuple[str, int, int]], output_path: Path):
    """Generate a preview image showing crop boundaries."""
    print(f"\nGenerating preview for: {image_path.name}")
    
    if not image_path.exists():
        print(f"  ERROR: File not found: {image_path}")
        return
    
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    params = get_grid_params(width, height)
    
    # Create overlay for drawing
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    
    print(f"  Image size: {width}x{height}")
    print(f"  Cell size: {params['cell_width']}x{params['cell_height']}")
    print(f"  Tile size: {params['tile_width']}x{params['tile_height']}")
    
    for name, col, row in tiles:
        x = params["left_margin"] + col * params["cell_width"]
        y = params["top_margin"] + row * params["cell_height"]
        x2 = x + params["tile_width"]
        y2 = y + params["tile_height"]
        
        # Draw rectangle outline (green = crop boundary)
        draw.rectangle([x, y, x2, y2], outline=(0, 255, 0, 255), width=2)
        
        # Draw corner markers (red = exact corners)
        marker_size = 6
        # Top-left
        draw.rectangle([x-1, y-1, x+marker_size, y+marker_size], fill=(255, 0, 0, 200))
        # Top-right
        draw.rectangle([x2-marker_size, y-1, x2+1, y+marker_size], fill=(255, 0, 0, 200))
        # Bottom-left
        draw.rectangle([x-1, y2-marker_size, x+marker_size, y2+1], fill=(255, 0, 0, 200))
        # Bottom-right
        draw.rectangle([x2-marker_size, y2-marker_size, x2+1, y2+1], fill=(255, 0, 0, 200))
        
        # Label
        draw.text((x + 5, y + 5), name, fill=(255, 255, 0, 255))
    
    # Composite overlay onto image
    result = Image.alpha_composite(img, overlay)
    result.save(output_path, "PNG")
    print(f"  Saved preview: {output_path.name}")


def process_image(image_path: Path, tiles: list[tuple[str, int, int]], output_dir: Path):
    """Process a single composite image and extract all tiles."""
    print(f"\nProcessing: {image_path.name}")
    
    if not image_path.exists():
        print(f"  ERROR: File not found: {image_path}")
        return
    
    img = Image.open(image_path)
    width, height = img.size
    params = get_grid_params(width, height)
    
    print(f"  Image size: {width}x{height}")
    print(f"  Cell size: {params['cell_width']}x{params['cell_height']}")
    print(f"  Tile size: {params['tile_width']}x{params['tile_height']}")
    
    extracted = 0
    for name, col, row in tiles:
        # Calculate tile position
        x = params["left_margin"] + col * params["cell_width"]
        y = params["top_margin"] + row * params["cell_height"]
        
        # Crop just the texture tile
        tile = img.crop((x, y, x + params["tile_width"], y + params["tile_height"]))
        
        # Save as PNG
        output_path = output_dir / f"{name}.png"
        tile.save(output_path, "PNG")
        print(f"  Extracted: {name}.png ({tile.size[0]}x{tile.size[1]})")
        extracted += 1
    
    print(f"  Total extracted: {extracted}")


def main():
    # Check for preview mode
    preview_mode = "--preview" in sys.argv or "-p" in sys.argv
    
    # Paths
    script_dir = Path(__file__).parent
    parent_dir = script_dir.parent
    output_dir = script_dir
    
    # Source images in parent directory (other/)
    image1_path = parent_dir / "terrain-raw-asphalt-limestone.png"
    image2_path = parent_dir / "terrain-raw-mud-air.png"
    
    # Create output directory if needed
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("=" * 50)
    if preview_mode:
        print("Terrain Tile Extractor - PREVIEW MODE")
    else:
        print("Terrain Tile Extractor")
    print("=" * 50)
    print(f"Output directory: {output_dir}")
    
    if preview_mode:
        # Generate preview images showing crop boundaries
        generate_preview(image1_path, IMAGE1_TILES, output_dir / "preview-1.png")
        generate_preview(image2_path, IMAGE2_TILES, output_dir / "preview-2.png")
        
        print("\n" + "=" * 50)
        print("Preview generated!")
        print("Open preview-1.png and preview-2.png to check crop boundaries.")
        print("")
        print("GREEN rectangles = crop boundaries")
        print("RED corners = exact corner positions")
        print("")
        print("To adjust, edit get_grid_params() in this script:")
        print("  - Increase top_margin to move crops DOWN")
        print("  - Increase left_margin to move crops RIGHT")
        print("  - Increase tile_width_ratio to capture MORE horizontally")
        print("  - Increase tile_height_ratio to capture MORE vertically")
        print("=" * 50)
    else:
        # Process both images
        process_image(image1_path, IMAGE1_TILES, output_dir)
        process_image(image2_path, IMAGE2_TILES, output_dir)
        
        print("\n" + "=" * 50)
        print("Extraction complete!")
        print(f"Check {output_dir} for extracted tiles.")
        print("Open terrain-verification.html to verify the results.")
        print("=" * 50)


if __name__ == "__main__":
    main()

