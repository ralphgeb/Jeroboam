"""Shrink the app's photos: every Resources/Photos/<id>.jpg becomes <id>.heic (HEIC quality 50, at most 1,200 px on the long side),
and the original moves to media/photos-original/<id>.jpg, kept in the repository but not shipped in the app.

Tested on all 696 photos (Nov 2026): 69 MB -> about 40 MB, SSIM 0.98+ even on the hardest photos, no visible difference at 2x zoom.
Run after adding photos (new ones arrive as .jpg):  python3 tools/compress_photos.py      (needs: pip install pillow-heif)
The app loads <id>.heic, else <id>.jpg (Photos.image), and build_content.py accepts both.
"""
import os, shutil, sys
from PIL import Image, ImageFile
import pillow_heif

pillow_heif.register_heif_opener()
ImageFile.LOAD_TRUNCATED_IMAGES = True   # one Commons file has a damaged colour-profile chunk; the pixels are fine

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PHOTOS = os.path.join(ROOT, "Jeroboam", "Resources", "Photos")
ORIGINALS = os.path.join(ROOT, "media", "photos-original")
MAX_SIDE, QUALITY = 1200, 50

def main():
    os.makedirs(ORIGINALS, exist_ok=True)
    before = after = n = 0
    for name in sorted(os.listdir(PHOTOS)):
        if not name.endswith(".jpg"):
            continue
        src = os.path.join(PHOTOS, name)
        pid = name[:-4]
        keep = os.path.join(ORIGINALS, name)
        if not os.path.exists(keep):
            shutil.copy2(src, keep)
        im = Image.open(keep)
        im.load()
        im = im.convert("RGB")
        if max(im.size) > MAX_SIDE:
            im.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
        dest = os.path.join(PHOTOS, pid + ".heic")
        im.save(dest, "HEIF", quality=QUALITY)
        before += os.path.getsize(src)
        after += os.path.getsize(dest)
        os.remove(src)
        n += 1
    if n:
        print(f"{n} photos: {before / 1e6:.1f} MB -> {after / 1e6:.1f} MB ({100 * (1 - after / before):.0f}% smaller); originals in media/photos-original")
    else:
        print("nothing to do")

if __name__ == "__main__":
    sys.exit(main())
