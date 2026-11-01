"""BC1 (DXT1) texture compression for card faces, written as DDS files with a
full mipmap chain, which Godot loads straight into video memory at an eighth
of the size of plain RGBA (plan: card-face-lod-plan.md). Godot can't compress
textures itself in an exported game, so the importer does it once.

Pillow can write BC1 too, but picks its colours too crudely for card text and
art; this fits each 4 × 4 block's two colours along the block's main colour
axis and refines them once by least squares, all vectorised with NumPy.
"""

import gzip
import struct

import numpy as np

# DDS header flags (Microsoft's DDS_HEADER).
_DDSD = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000  # caps, height, width, pixel format, mipmap count, linear size
_DDPF_FOURCC = 0x4
_DDSCAPS = 0x8 | 0x1000 | 0x400000  # complex, texture, mipmap


def mip_sizes(width, height):
    """Each mipmap level's size, down to 1 × 1, halving as Godot does."""
    sizes = [(width, height)]
    while sizes[-1] != (1, 1):
        w, h = sizes[-1]
        sizes.append((max(1, w // 2), max(1, h // 2)))
    return sizes


def dds_bytes(image, mipmaps=True):
    """A Pillow RGB image as a BC1 DDS file, with every mipmap level when
    `mipmaps` is set (each made by box-filtering the full image down)."""
    from PIL import Image

    image = image.convert("RGB")
    levels = mip_sizes(*image.size) if mipmaps else [image.size]
    # Every level's blocks in one go: far quicker than level by level.
    blocks = [to_blocks(np.asarray(image if size == image.size else image.resize(size, Image.BOX), dtype=np.uint8))
              for size in levels]
    data = encode_blocks(np.concatenate(blocks)).tobytes()
    return header(image.size, len(levels), len(blocks[0]) * 8) + data


def dds_gz_bytes(image):
    """dds_bytes(), gzipped: card faces shrink by about a third, and Godot
    unzips them in well under a millisecond."""
    return gzip.compress(dds_bytes(image), compresslevel=6, mtime=0)


def header(size, levels, top_bytes):
    width, height = size
    pixel_format = struct.pack("<II4s5I", 32, _DDPF_FOURCC, b"DXT1", 0, 0, 0, 0, 0)
    fields = struct.pack("<7I", 124, _DDSD, height, width, top_bytes, 0, levels) + bytes(44) + pixel_format
    fields += struct.pack("<5I", _DDSCAPS, 0, 0, 0, 0)
    return b"DDS " + fields


def encode(pixels):
    """BC1 blocks for an H × W × 3 uint8 array, rows of blocks top to bottom."""
    return encode_blocks(to_blocks(pixels)).tobytes()


def to_blocks(pixels):
    """An H × W × 3 uint8 array as N × 16 × 3 float blocks, rows of blocks top
    to bottom. Sizes that aren't a multiple of 4 are padded by repeating the
    edge."""
    height, width = pixels.shape[:2]
    pad_h, pad_w = -height % 4, -width % 4
    if pad_h or pad_w:
        pixels = np.pad(pixels, ((0, pad_h), (0, pad_w), (0, 0)), mode="edge")
    rows, cols = pixels.shape[0] // 4, pixels.shape[1] // 4
    return pixels.reshape(rows, 4, cols, 4, 3).swapaxes(1, 2).reshape(-1, 16, 3).astype(np.float32)


def encode_blocks(blocks):
    """N × 16 × 3 float pixels (0-255) to N BC1 blocks (N × 8 uint8)."""
    mean = blocks.mean(axis=1, keepdims=True)
    centred = blocks - mean
    cov = np.einsum("nki,nkj->nij", centred, centred)
    # Main colour axis by power iteration, starting from the spread's
    # largest diagonal (flat blocks keep a harmless default axis).
    axis = np.ones((len(blocks), 3), np.float32)
    for _ in range(8):
        axis = np.einsum("nij,nj->ni", cov, axis)
        norm = np.linalg.norm(axis, axis=1, keepdims=True)
        axis = np.where(norm > 1e-6, axis / np.maximum(norm, 1e-6), 0.57735)
    t = np.einsum("nki,ni->nk", centred, axis)
    lo = mean[:, 0] + axis * t.min(axis=1, keepdims=True)
    hi = mean[:, 0] + axis * t.max(axis=1, keepdims=True)
    c0, c1 = _quantize(hi), _quantize(lo)
    indices = _pick(blocks, c0, c1)
    # One least-squares refinement of the two end colours for those indices.
    weight = np.array([1.0, 0.0, 2 / 3, 1 / 3], np.float32)[indices]  # share of c0 per pixel
    a, b = weight, 1.0 - weight
    aa, bb, ab = (a * a).sum(1), (b * b).sum(1), (a * b).sum(1)
    det = aa * bb - ab * ab
    ok = np.abs(det) > 1e-3
    ax = np.einsum("nk,nki->ni", a, blocks)
    bx = np.einsum("nk,nki->ni", b, blocks)
    safe = np.where(ok, det, 1.0)[:, None]
    new0 = (bb[:, None] * ax - ab[:, None] * bx) / safe
    new1 = (aa[:, None] * bx - ab[:, None] * ax) / safe
    c0 = np.where(ok[:, None], _quantize(new0), c0)
    c1 = np.where(ok[:, None], _quantize(new1), c1)
    indices = _pick(blocks, c0, c1)
    return _pack(c0, c1, indices)


def _quantize(colors):
    """Float RGB to 5:6:5 integer channels."""
    colors = np.clip(colors, 0, 255)
    return np.stack([np.rint(colors[:, 0] * 31 / 255), np.rint(colors[:, 1] * 63 / 255),
                     np.rint(colors[:, 2] * 31 / 255)], axis=1).astype(np.int32)


def _expand(c):
    return np.stack([c[:, 0] * 255 / 31, c[:, 1] * 255 / 63, c[:, 2] * 255 / 31], axis=1).astype(np.float32)


def _value(c):
    return (c[:, 0] << 11) | (c[:, 1] << 5) | c[:, 2]


def _pick(blocks, c0, c1):
    """Each pixel's nearest of the block's four colours. Indices are for the
    order c0, c1, 2/3 c0 + 1/3 c1, 1/3 c0 + 2/3 c1. The four lie on one line,
    so the nearest is found by where a pixel falls along it."""
    e0, e1 = _expand(c0), _expand(c1)
    span = e1 - e0
    length = (span * span).sum(axis=1, keepdims=True)
    t = np.einsum("nki,ni->nk", blocks - e0[:, None, :], span) / np.maximum(length, 1e-6)
    step = np.clip(np.rint(t * 3), 0, 3).astype(np.int32)
    return np.array([0, 2, 3, 1])[step]


def _pack(c0, c1, indices):
    """Writes the blocks, swapping the ends where needed: four-colour mode
    needs colour 0's value above colour 1's."""
    v0, v1 = _value(c0), _value(c1)
    swap = v0 < v1
    v0, v1 = np.where(swap, v1, v0), np.where(swap, v0, v1)
    indices = np.where(swap[:, None], np.array([1, 0, 3, 2])[indices], indices)
    # Equal ends would mean three-colour mode; every index then reads colour 0.
    indices = np.where((v0 == v1)[:, None], 0, indices)
    bits = (indices.astype(np.uint32) << (2 * np.arange(16, dtype=np.uint32))).sum(axis=1, dtype=np.uint32)
    out = np.empty((len(v0), 8), np.uint8)
    out[:, 0], out[:, 1] = v0 & 0xFF, v0 >> 8
    out[:, 2], out[:, 3] = v1 & 0xFF, v1 >> 8
    out[:, 4:8] = bits.astype("<u4").view(np.uint8).reshape(-1, 4)
    return out
