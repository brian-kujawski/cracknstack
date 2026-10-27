#!/usr/bin/env python3
"""cardflat - flatten photos of trading cards into straight-on PNGs.

Give it a photo of a single card lying out of its sleeve on a surface that
contrasts with the card's border. Several detectors propose outlines (colour
distance, colour histogram of the surroundings, edge contours) and the one whose
four sides sit best on real image edges wins, which copes with textured tables
such as wood grain. It then fits each of the four edges as a gently
curved line (ignoring the rounded corners), takes the virtual square corners
where those edges meet, and warps the card so all four edges are straight and
the result is 63 x 88 mm.

Perspective is removed with a homography. Any bow left in the edges after that
(lens distortion, or physical curl, which the outline alone cannot tell apart)
is forced straight with a smooth warp blended in from the four edges. If the
fit looks unreliable, the PNG is still written and a warning is printed.

Usage:
    python cardflat.py photo.jpg                  # writes photo_flat.png
    python cardflat.py *.jpg -o flat/ --debug     # batch, plus overlay images
    python cardflat.py photo.jpg --height 1040    # fixed output height in px
    python cardflat.py photo.jpg --size 59x86     # Yu-Gi-Oh!/Japanese-size cards

When detection goes wrong, place the corners yourself. Clicks only need to be
roughly right; the edges are still traced precisely from them:
    python cardflat.py photo.jpg --pick           # window, pre-filled with the auto result
    python cardflat.py *.jpg --pick-if-warned     # window only for doubtful photos
    python cardflat.py photo.jpg --corners 859,1108,2135,1074,2099,2834,944,2806
                                                  # TL, TR, BR, BL in photo pixels
In the window: drag a corner to move it, click to add one (top-left first, then
clockwise, as the card should appear upright), right-click to remove, F to flip
which end is the top, A to restore the automatic corners, R to clear, Enter to
accept, S to skip, Q to quit the batch.

Requires: Python 3.8+, opencv-python (not -headless, for the window), numpy
"""

import argparse
import os
import sys

import cv2
import numpy as np

DEFAULT_SIZE_MM = (63.0, 88.0)
DEFAULT_CORNER_RADIUS_MM = 3.0

DETECT_MAX_DIM = 1000   # outline detection runs on a copy this size
TRIM = 0.10             # ignore this fraction of each edge at both ends (rounded corners)
EDGE_SAMPLES = 200      # points sampled along each edge at full resolution
OUTER_SEARCH_MM = (0.4, 6.0)  # band outside a traced edge searched for a faint outer edge

# Confidence thresholds, measured in millimetres on the flattened card unless noted.
WARN_RESIDUAL_MM = 0.12     # edge points scattered around the fitted curve (ragged edge)
WARN_INLIER_FRAC = 0.80     # share of edge samples that agree with the fitted curve
WARN_BOW_MM = 1.2           # edge bowed more than lens distortion plausibly causes
WARN_MIXED_BOW_MM = 0.35    # some edges bow outward and others inward by at least this
WARN_EDGE_CONTRAST = 12.0   # median brightness step across the edge, 0-255 levels
WARN_CONTRAST_RATIO = 0.35  # weakest edge vs strongest edge (shadows show up this way)
WARN_OUTLINE_SCORE = 3.0    # outline's weakest side vs typical background texture
WARN_AREA_FRAC = 0.02       # card covers less of the photo than this
WARN_SIDE_RATIO = 1.10      # long/short side ratio below this: orientation is a guess
NOTE_MIN_HEIGHT_PX = 600    # source has fewer pixels than this along the card's height

WARNING_TEXT = ("WARNING: OpenCV confidence low, image output may be distorted "
                "or incorrect, review manually")

EDGE_NAMES = ("top", "right", "bottom", "left")


class CardError(Exception):
    """No usable output could be produced for this image."""


def cross2(a, b):
    return a[0] * b[1] - a[1] * b[0]


# --------------------------------------------------------------------------- loading

def load_image(path):
    if not os.path.isfile(path):
        raise CardError("file not found")
    img = cv2.imread(path, cv2.IMREAD_COLOR)  # applies EXIF orientation
    if img is None:
        # cv2.imread cannot open some non-ASCII paths on Windows
        try:
            data = np.fromfile(path, dtype=np.uint8)
            img = cv2.imdecode(data, cv2.IMREAD_COLOR) if data.size else None
        except OSError:
            img = None
    if img is None:
        raise CardError("could not read image")
    return img


# ---------------------------------------------------------------------- segmentation

def largest_filled(mask):
    """Largest connected blob of a binary mask, with holes filled, plus its contour."""
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    if not contours:
        return None, None
    c = max(contours, key=cv2.contourArea)
    out = np.zeros_like(mask)
    cv2.drawContours(out, [c], -1, 255, cv2.FILLED)
    return out, c


def border_pixels(img, b):
    return np.concatenate([img[:b].reshape(-1, img.shape[2]), img[-b:].reshape(-1, img.shape[2]),
                           img[:, :b].reshape(-1, img.shape[2]), img[:, -b:].reshape(-1, img.shape[2])])


def clean_mask(mask, kernel):
    """Close gaps, fill holes, remove specks, keep the largest blob."""
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(mask, contours, -1, 255, cv2.FILLED)      # fill holes first
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return largest_filled(mask)


def smooth_hist(hist):
    """Blur a 3-D colour histogram so nearby colours count as similar."""
    kern = np.array([1, 4, 6, 4, 1], np.float64) / 16
    for axis in range(3):
        pad = [(2, 2) if i == axis else (0, 0) for i in range(3)]
        p = np.pad(hist, pad, mode="edge")
        n = hist.shape[axis]
        hist = sum(kern[j] * np.take(p, np.arange(j, j + n), axis=axis) for j in range(5))
    return hist


def histogram_mask(lab_u8, b, kernel):
    """Card = colours rarely seen around the photo's border. Unlike a single average
    background colour, this treats both the light wood and its dark grain as table."""
    bins = 32
    q = (lab_u8.astype(np.int32) * bins) // 256
    qb = border_pixels(q, b)
    hist = np.zeros((bins, bins, bins))
    np.add.at(hist, (qb[:, 0], qb[:, 1], qb[:, 2]), 1)
    hist = smooth_hist(smooth_hist(hist))
    p = hist[q[..., 0], q[..., 1], q[..., 2]]
    pb = hist[qb[:, 0], qb[:, 1], qb[:, 2]]
    thr = np.percentile(pb, 1.0)
    fg = (p < thr).astype(np.uint8) * 255
    return clean_mask(fg, kernel)


def edge_contours(gray):
    """Closed outlines from an edge map; a card's outline is usually one of them."""
    gmag = cv2.magnitude(cv2.Sobel(gray, cv2.CV_32F, 1, 0), cv2.Sobel(gray, cv2.CV_32F, 0, 1))
    hi = float(np.percentile(gmag, 95))
    edges = cv2.Canny(gray, max(hi / 3, 20), max(hi, 40), L2gradient=True)
    edges = cv2.dilate(edges, np.ones((3, 3), np.uint8))
    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    min_area = 0.003 * gray.shape[0] * gray.shape[1]
    contours = [c for c in contours if cv2.contourArea(cv2.convexHull(c)) > min_area]
    contours.sort(key=lambda c: cv2.contourArea(cv2.convexHull(c)), reverse=True)
    return contours[:40]


def outline_candidates(small):
    """Possible card outlines from several detectors, as (label, contour) pairs.
    Each detector fails differently; choose_outline() decides between them."""
    h, w = small.shape[:2]
    blur = cv2.GaussianBlur(small, (0, 0), 1.5)
    lab_u8 = cv2.cvtColor(blur, cv2.COLOR_BGR2LAB)
    b = max(3, int(round(0.02 * min(h, w))))
    k = max(3, int(round(0.01 * min(h, w))) | 1)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
    cands = []

    rough, gc = distance_masks(small, lab_u8.astype(np.float32), b, kernel, k)
    for label, m in (("colour distance", rough), ("grabcut", gc)):
        if m is not None:
            cands.append((label, largest_filled(m)[1]))
    _, c = histogram_mask(lab_u8, b, kernel)
    if c is not None:
        cands.append(("colour histogram", c))
    for c in edge_contours(cv2.cvtColor(blur, cv2.COLOR_BGR2GRAY)):
        cands.append(("edges", c))
    return cands


def distance_masks(small, lab, b, kernel, k):
    """Card = pixels far from the average border colour; plus a GrabCut refinement.
    Works well on plain tables, leaks along dark grain on textured ones."""
    h, w = small.shape[:2]
    border = border_pixels(lab, b)
    bg = np.median(border, axis=0)
    dist = np.linalg.norm(lab - bg, axis=2)
    # Robust spread of the background colour (the card may cover part of the border).
    bd = np.linalg.norm(border - bg, axis=1)
    noise = float(np.median(bd) + 3 * 1.4826 * np.median(np.abs(bd - np.median(bd))))

    scale = 255.0 / max(float(dist.max()), 1e-6)
    t, _ = cv2.threshold((dist * scale).astype(np.uint8), 0, 255,
                         cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # Otsu alone can drop card areas whose colour is close to the table, so take
    # the more inclusive of Otsu and a noise-based threshold.
    thr = max(min(t / scale, 2.5 * noise), 8.0)
    rough, _ = clean_mask((dist > thr).astype(np.uint8) * 255, kernel)
    if rough is None:
        return None, None

    # GrabCut tightens the colour-distance mask around the real boundary.
    big = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (4 * k + 1, 4 * k + 1))
    gc = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    gc[rough > 0] = cv2.GC_PR_FGD
    gc[cv2.erode(rough, big) > 0] = cv2.GC_FGD
    gc[cv2.dilate(rough, big) == 0] = cv2.GC_BGD
    try:
        bgm = np.zeros((1, 65), np.float64)
        fgm = np.zeros((1, 65), np.float64)
        cv2.grabCut(small, gc, None, bgm, fgm, 4, cv2.GC_INIT_WITH_MASK)
        fg = np.where((gc == cv2.GC_FGD) | (gc == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
        fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, kernel)
        refined, _ = largest_filled(fg)
        return rough, refined
    except cv2.error:
        return rough, None


# ----------------------------------------------------------------------- outline

def rough_quad(contour):
    """Reduce the outline's convex hull to the 4 vertices that keep the most area."""
    pts = [p for p in cv2.convexHull(contour).reshape(-1, 2).astype(np.float64)]
    if len(pts) < 4:
        return None
    while len(pts) > 4:
        n = len(pts)
        loss = [abs(cross2(pts[i] - pts[i - 1], pts[(i + 1) % n] - pts[i - 1]))
                for i in range(n)]
        pts.pop(int(np.argmin(loss)))
    return np.array(pts)


def clockwise(pts):
    """Return points in clockwise order as seen in the image (y axis pointing down)."""
    x, y = pts[:, 0], pts[:, 1]
    area2 = np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y)
    return pts if area2 > 0 else pts[::-1].copy()


def order_corners(q):
    """Order as TL, TR, BR, BL with the long sides vertical (portrait)."""
    q = clockwise(q)
    side = [np.linalg.norm(q[(i + 1) % 4] - q[i]) for i in range(4)]
    a, b = side[0] + side[2], side[1] + side[3]
    ratio = max(a, b) / max(min(a, b), 1e-9)
    starts = (0, 2) if a < b else (1, 3)       # the two short sides
    start = min(starts, key=lambda s: (q[s][1] + q[(s + 1) % 4][1]) / 2)  # higher one = top
    q = np.roll(q, -start, axis=0)
    long_vec = q[3] - q[0]
    sideways = abs(long_vec[0]) > abs(long_vec[1])
    return q, ratio, sideways


def quad_area(q):
    x, y = q[:, 0], q[:, 1]
    return 0.5 * abs(np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y))


def plausible_quad(q, shape):
    """Could this quadrilateral be a card seen at a reasonable angle?"""
    h, w = shape[:2]
    if quad_area(q) < 0.003 * h * w:
        return False
    for i in range(4):
        a, b = q[i - 1] - q[i], q[(i + 1) % 4] - q[i]
        cosang = a @ b / max(np.linalg.norm(a) * np.linalg.norm(b), 1e-9)
        if not -0.77 < cosang < 0.77:          # corner angles between ~40 and ~140 degrees
            return False
    side = [np.linalg.norm(q[(i + 1) % 4] - q[i]) for i in range(4)]
    a, b = side[0] + side[2], side[1] + side[3]
    return max(a, b) / max(min(a, b), 1e-9) < 3.0


def side_strengths(grads, q, samples=60):
    """How well each side of quad q sits on a real edge: the 25th-percentile of the
    gradient across the side (best within ~1% of the card's size, since rough corners
    sit a little off), so a side must be edge along most of its length. A blob that
    leaked into wood grain has sides crossing open table."""
    reach = max(2, int(round(0.01 * np.sqrt(quad_area(q)) * 1.2)))
    out = []
    for i in range(4):
        a, b = q[i], q[(i + 1) % 4]
        d = b - a
        L = np.linalg.norm(d)
        if L < 1:
            out.append(0.0)
            continue
        n = np.array([-d[1], d[0]]) / L
        base = a + np.linspace(0.12, 0.88, samples)[:, None] * d
        pts = base[:, None, :] + np.arange(-reach, reach + 1)[None, :, None] * n
        mx, my = pts[..., 0].astype(np.float32), pts[..., 1].astype(np.float32)
        proj = np.zeros(mx.shape, np.float32)
        for gx, gy in grads:
            sx = cv2.remap(gx, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
            sy = cv2.remap(gy, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
            proj = np.maximum(proj, np.abs(sx * n[0] + sy * n[1]))
        out.append(float(np.percentile(proj.max(axis=1), 25)))
    return np.array(out)


def choose_outline(small, cands):
    """Score every candidate outline and pick the card.

    Returns (label, contour, rough quad, score, texture level) or None. Candidates
    whose weakest side scores at least 45% of the best (and well above the
    background texture) are treated as equally good,
    and the largest of those wins, so the card's outer edge beats the edge of its
    border or art box, which are also strong rectangles."""
    blur = cv2.GaussianBlur(small, (0, 0), 1.0).astype(np.float32)
    grads = [(cv2.Sobel(blur[..., c], cv2.CV_32F, 1, 0, ksize=3) / 8,
              cv2.Sobel(blur[..., c], cv2.CV_32F, 0, 1, ksize=3) / 8) for c in range(3)]
    gmag = np.max([cv2.magnitude(gx, gy) for gx, gy in grads], axis=0)
    texture = float(np.percentile(gmag, 75))

    scored = []
    for label, c in cands:
        if c is None or len(c) < 4:
            continue
        q = rough_quad(c)
        if q is None:
            continue
        q = clockwise(q)
        if not plausible_quad(q, small.shape):
            continue
        s = side_strengths(grads, q)
        scored.append((float(s.min()), quad_area(q), label, c, q))
    if not scored:
        return None
    best = max(sc[0] for sc in scored)
    floor = max(0.45 * best, 2.0 * texture)
    pool = [sc for sc in scored if sc[0] >= floor] or [max(scored, key=lambda sc: sc[0])]
    score, _, label, c, q = max(pool, key=lambda sc: sc[1])
    return label, c, q, score, texture


# ------------------------------------------------------------------------- edges

class Edge:
    """A card edge: chord from pa to pb plus a quadratic bow along the chord normal."""

    def __init__(self, pa, pb, coef=(0.0, 0.0, 0.0)):
        self.pa = np.asarray(pa, np.float64)
        d = np.asarray(pb, np.float64) - self.pa
        self.L = float(np.linalg.norm(d))
        self.u = d / self.L
        self.n = np.array([-self.u[1], self.u[0]])   # points into the card
        self.coef = np.asarray(coef, np.float64)

    def tn(self, t):
        return (t - self.L / 2) / (self.L / 2)

    def local(self, pts):
        rel = pts - self.pa
        return rel @ self.u, rel @ self.n

    def point(self, t):
        t = np.asarray(t, np.float64)
        f = np.polyval(self.coef, self.tn(t))
        return self.pa + t[..., None] * self.u + f[..., None] * self.n

    def deriv(self, t):
        return self.u + np.polyval(np.polyder(self.coef), self.tn(t)) * (2 / self.L) * self.n


def contour_arc(contour, pa, pb):
    """Contour points running clockwise from the point nearest pa to the one nearest pb."""
    ia = int(np.argmin(np.sum((contour - pa) ** 2, axis=1)))
    ib = int(np.argmin(np.sum((contour - pb) ** 2, axis=1)))
    if ib >= ia:
        return contour[ia:ib + 1]
    return np.concatenate([contour[ia:], contour[:ib + 1]])


def edge_gradient(img, base, n, steps):
    """Colour gradient magnitude (levels per px) along the normal n, sampled at
    base + step * n for each base point (rows) and each step (columns, 0.5 px apart)."""
    coords = base[:, None, :] + steps[None, :, None] * n
    # Work on a float crop around these samples only, to keep memory small.
    h, w = img.shape[:2]
    x0 = max(int(np.floor(coords[..., 0].min())) - 3, 0)
    y0 = max(int(np.floor(coords[..., 1].min())) - 3, 0)
    x1 = min(int(np.ceil(coords[..., 0].max())) + 4, w)
    y1 = min(int(np.ceil(coords[..., 1].max())) + 4, h)
    if x1 - x0 < 3 or y1 - y0 < 3:
        return np.zeros(coords.shape[:2])
    crop = cv2.GaussianBlur(img[y0:y1, x0:x1].astype(np.float32), (0, 0), 1.0)
    mx = (coords[..., 0] - x0).astype(np.float32)
    my = (coords[..., 1] - y0).astype(np.float32)
    prof = cv2.remap(crop, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    if prof.ndim == 2:
        prof = prof[..., None]
    grad = np.linalg.norm(np.gradient(prof, axis=1), axis=2) / 0.5
    # Samples that fell outside the photo carry no information.
    outside = (coords[..., 0] < 0) | (coords[..., 1] < 0) | (coords[..., 0] > w - 1) | (coords[..., 1] > h - 1)
    grad[outside] = 0
    return grad


def refine_edge(img, edge, arc, window, prefer_near=False):
    """Search across the edge at full resolution for the strongest brightness step.
    With prefer_near, steps far from the starting line count for less, so a faint
    edge where the user clicked beats a strong one elsewhere in the window."""
    t_c, f_c = edge.local(arc)
    order = np.argsort(t_c)
    ts = np.linspace(TRIM * edge.L, (1 - TRIM) * edge.L, EDGE_SAMPLES)
    f0 = np.interp(ts, t_c[order], f_c[order])
    steps = np.arange(-window, window + 0.25, 0.5)
    base = edge.pa + ts[:, None] * edge.u + f0[:, None] * edge.n
    grad = edge_gradient(img, base, edge.n, steps)

    rows = np.arange(len(ts))
    pick = grad * np.exp(-0.5 * (steps / (0.4 * window)) ** 2) if prefer_near else grad
    k = pick.argmax(axis=1)
    if prefer_near:   # the weighting picks which peak; climb onto that peak's true top
        for _ in range(4):
            up = np.clip(k + 1, 0, len(steps) - 1)
            dn = np.clip(k - 1, 0, len(steps) - 1)
            k = np.where(grad[rows, up] > grad[rows, k], up,
                         np.where(grad[rows, dn] > grad[rows, k], dn, k))
    kk = np.clip(k, 1, len(steps) - 2)
    g0, g1, g2 = grad[rows, kk - 1], grad[rows, kk], grad[rows, kk + 1]
    denom = g0 - 2 * g1 + g2
    safe = np.where(np.abs(denom) > 1e-9, denom, 1.0)
    off = np.where(np.abs(denom) > 1e-9, 0.5 * (g0 - g2) / safe, 0.0)
    pos = steps[kk] + np.clip(off, -0.5, 0.5) * 0.5
    valid = (k > 0) & (k < len(steps) - 1)        # peak at the window edge = no edge found
    pts = base + pos[:, None] * edge.n
    return pts, grad[rows, kk], valid


def fit_edge(pa, pb, pts, ok):
    """Robust quadratic fit of the edge points; returns the Edge and an inlier mask."""
    edge = Edge(pa, pb)
    t, f = edge.local(pts)
    tn = edge.tn(t)
    inl = ok.copy()
    for _ in range(5):
        if inl.sum() < 10:
            break
        coef = np.polyfit(tn[inl], f[inl], 2)
        r = f - np.polyval(coef, tn)
        mad = 1.4826 * np.median(np.abs(r[inl]))
        new = ok & (np.abs(r) < max(3 * mad, 0.75))
        edge.coef = coef
        if np.array_equal(new, inl):
            break
        inl = new
    return edge, inl


def outer_edge(img, edge, px_per_mm):
    """Look just outside a traced edge for a fainter step running parallel to it,
    which is what a dark card border on a dark table looks like once the bright
    card interior has been taken for the card.

    Returns (share of samples agreeing on one outer step, its median offset in mm)."""
    ts = np.linspace(TRIM * edge.L, (1 - TRIM) * edge.L, EDGE_SAMPLES)
    base = edge.point(ts)
    start = max(OUTER_SEARCH_MM[0] * px_per_mm, 4.0)
    steps = -np.arange(start, OUTER_SEARCH_MM[1] * px_per_mm, 0.5)    # negative = outward
    if len(steps) < 6:
        return 0.0, 0.0
    grad = edge_gradient(img, base, edge.n, steps)
    k = grad.argmax(axis=1)
    peak = grad[np.arange(len(ts)), k]
    floor = np.median(grad, axis=1)
    # A peak at the first step is just the tail of the edge already traced.
    found = (peak > 1.5) & (peak > 4 * floor) & (k > 0) & (k < len(steps) - 1)
    if found.sum() < 0.5 * len(ts):
        return float(found.mean()), 0.0
    off = -steps[k] / px_per_mm
    med = float(np.median(off[found]))
    consistent = found & (np.abs(off - med) < 0.3)
    return float(consistent.mean()), med


def intersect(e1, e2):
    """Corner where the end of e1 meets the start of e2 (Newton on the two curves)."""
    t, s = e1.L, 0.0
    for _ in range(30):
        F = e1.point(t) - e2.point(s)
        J = np.column_stack([e1.deriv(t), -e2.deriv(s)])
        try:
            step = np.linalg.solve(J, F)
        except np.linalg.LinAlgError:
            break
        t, s = t - step[0], s - step[1]
        if np.abs(step).max() < 1e-7:
            break
    return (e1.point(t) + e2.point(s)) / 2


# ------------------------------------------------------------------ rectification

def bow_basis(s):
    return np.column_stack([s * (1 - s), s * s * (1 - s)])


def bow_eval(coef, s):
    return s * (1 - s) * (coef[0] + coef[1] * s)


def edge_bows(H, edge_pts, Wr, Hr):
    """In the homography-corrected frame, fit how far each edge still bows.

    Returns, per edge: (coef, residuals_px, outward_sign). The bow is a cubic that
    is zero at both corners: d(s) = s(1-s)(a + b s), s from 0 to 1 along the edge.
    """
    out = []
    for i, pts in enumerate(edge_pts):
        p = cv2.perspectiveTransform(pts.reshape(-1, 1, 2).astype(np.float64), H).reshape(-1, 2)
        if i == 0:
            s, d, sign = p[:, 0] / Wr, p[:, 1], -1.0
        elif i == 1:
            s, d, sign = p[:, 1] / Hr, p[:, 0] - Wr, 1.0
        elif i == 2:
            s, d, sign = p[:, 0] / Wr, p[:, 1] - Hr, 1.0
        else:
            s, d, sign = p[:, 1] / Hr, p[:, 0], -1.0
        keep = (s > 0) & (s < 1)
        s, d = s[keep], d[keep]
        if len(s) < 5:
            out.append((np.zeros(2), np.zeros(0), sign))
            continue
        coef, *_ = np.linalg.lstsq(bow_basis(s), d, rcond=None)
        out.append((coef, d - bow_basis(s) @ coef, sign))
    return out


def render(img, H, bows, Wr, Hr, Wo, Ho, bend=True):
    """Sample the flattened card at Wo x Ho. Output pixel centres map into the
    Wr x Hr rectified frame, get the edge-blended bow added back (Coons patch),
    then go through the inverse homography into the source photo."""
    Hinv = np.linalg.inv(H)
    out = np.empty((Ho, Wo, 3), np.uint8)
    xs = (np.arange(Wo) + 0.5) * (Wr / Wo)
    u = xs / Wr
    top, right, bottom, left = (b[0] for b in bows)
    for y0 in range(0, Ho, 256):
        y1 = min(y0 + 256, Ho)
        ys = (np.arange(y0, y1) + 0.5) * (Hr / Ho)
        gx, gy = np.meshgrid(xs, ys)
        if bend:
            uu, vv = np.meshgrid(u, ys / Hr)
            gy = gy + (1 - vv) * bow_eval(top, uu) + vv * bow_eval(bottom, uu)
            gx = gx + (1 - uu) * bow_eval(left, vv) + uu * bow_eval(right, vv)
        den = Hinv[2, 0] * gx + Hinv[2, 1] * gy + Hinv[2, 2]
        mx = ((Hinv[0, 0] * gx + Hinv[0, 1] * gy + Hinv[0, 2]) / den).astype(np.float32)
        my = ((Hinv[1, 0] * gx + Hinv[1, 1] * gy + Hinv[1, 2]) / den).astype(np.float32)
        out[y0:y1] = cv2.remap(img, mx, my, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    return out


def corner_alpha(Wo, Ho, r):
    """Alpha channel with anti-aliased rounded corners of radius r pixels."""
    alpha = np.full((Ho, Wo), 255, np.uint8)
    R = int(np.ceil(r))
    if R < 1:
        return alpha
    yy, xx = np.mgrid[0:R, 0:R] + 0.5
    dist = np.hypot(xx - r, yy - r)
    patch = np.clip(r - dist + 0.5, 0, 1)
    patch[(xx > r) | (yy > r)] = 1.0          # only the curved quadrant is cut
    patch = (patch * 255).round().astype(np.uint8)
    alpha[:R, :R] = patch
    alpha[:R, -R:] = patch[:, ::-1]
    alpha[-R:, :R] = patch[::-1, :]
    alpha[-R:, -R:] = patch[::-1, ::-1]
    return alpha


# ------------------------------------------------------------------------ pipeline

def manual_quad(corners, warnings):
    """Corners given by hand: intended as top-left, top-right, bottom-right,
    bottom-left of the card, so the clicks also settle which way is up."""
    q = np.asarray(corners, np.float64).reshape(4, 2)
    if quad_area(q) < 1:
        raise CardError("the four corners given do not enclose an area")
    first = q[0].copy()
    q = clockwise(q)
    q = np.roll(q, -int(np.argmin(np.sum((q - first) ** 2, axis=1))), axis=0)
    side = [np.linalg.norm(q[(i + 1) % 4] - q[i]) for i in range(4)]
    if side[0] + side[2] > side[1] + side[3]:
        warnings.append("the corners given make the card wider than tall, so they were not "
                        "clicked starting at the top-left; orientation was guessed instead")
        q, _, _ = order_corners(q)
    return q


def flatten(img, size_mm=DEFAULT_SIZE_MM, height=None, bend=True, corners=None):
    """Find and flatten the card. Returns (bgr_image, info dict).

    corners: optional 4 (x, y) points in the photo, roughly at the card's
    top-left, top-right, bottom-right and bottom-left. They replace automatic
    outline detection; the edges are still traced precisely from there."""
    card_w_mm, card_h_mm = size_mm
    warnings, notes = [], []
    h, w = img.shape[:2]

    if corners is not None:
        q = manual_quad(corners, warnings)
        dense = np.linspace(0, 1, 200, endpoint=False)[:, None]
        contour_full = np.concatenate([q[i] + dense * (q[(i + 1) % 4] - q[i]) for i in range(4)])
        mean_side = np.mean([np.linalg.norm(q[(i + 1) % 4] - q[i]) for i in range(4)])
        window = 0.025 * mean_side + 4.0       # clicks are rough; card borders sit ~5% in
        k = max(1.0, max(h, w) / DETECT_MAX_DIM)
        source = "manual corners"
        outline_score = None
    else:
        s = min(1.0, DETECT_MAX_DIM / max(h, w))
        small = cv2.resize(img, (int(round(w * s)), int(round(h * s))),
                           interpolation=cv2.INTER_AREA) if s < 1 else img.copy()
        chosen = choose_outline(small, outline_candidates(small))
        if chosen is None:
            raise CardError("no card-shaped outline found; try --pick to click the corners")
        source, contour, q, outline_score, texture = chosen
        sh, sw = small.shape[:2]
        area_frac = quad_area(q) / (sh * sw)
        if area_frac < WARN_AREA_FRAC:
            warnings.append(f"card covers only {area_frac:.1%} of the photo")
        if outline_score < WARN_OUTLINE_SCORE * max(texture, 1.0):
            warnings.append("the outline found is not clearly the card: its sides are barely "
                            "stronger than the background texture (try --pick)")
        k = 1.0 / s
        window = 3.0 * k + 4.0
        contour_full = (contour.reshape(-1, 2).astype(np.float64) + 0.5) * k - 0.5
        contour_full = clockwise(contour_full)
        q = (q + 0.5) * k - 0.5
        q, side_ratio, sideways = order_corners(q)
        if side_ratio < WARN_SIDE_RATIO:
            warnings.append(f"long and short sides look similar (ratio {side_ratio:.2f}); "
                            "orientation and corner pairing are guesses")
        if sideways:
            notes.append("card lies sideways in the photo, so which end is the top is a guess; "
                         "use --rotate 180 if the output is upside down")

    # Refine each edge at full resolution and fit its curve.
    def trace(i, arc, window):
        pa, pb = q[i], q[(i + 1) % 4]
        pts, strength, ok = refine_edge(img, Edge(pa, pb), arc, window,
                                        prefer_near=corners is not None)
        edge, inl = fit_edge(pa, pb, pts, ok)
        if inl.sum() < 10:
            return None
        return edge, pts, inl, strength[inl]

    traced = [trace(i, contour_arc(contour_full, q[i], q[(i + 1) % 4]), window)
              for i in range(4)]

    # A dark border on a dark table can vanish, leaving the bright interior traced
    # as the card. Look for a fainter parallel edge a few mm further out.
    if all(traced):
        ppm = [traced[i][0].L / (card_w_mm if i % 2 == 0 else card_h_mm) for i in range(4)]
        outer = [outer_edge(img, traced[i][0], ppm[i]) for i in range(4)]
        strong = [frac >= 0.7 for frac, _ in outer]
        offs = [off for _, off in outer]
        if all(strong) and max(offs) - min(offs) < max(0.75, 0.3 * np.mean(offs)):
            ts = np.linspace(0, 1, 400)
            moved = []
            for i in range(4):
                e = traced[i][0]
                arc = e.point(ts * e.L) - e.n * (offs[i] * ppm[i])
                moved.append(trace(i, arc, max(3.0, 0.5 * ppm[i])))
            if all(moved):
                traced = moved
                notes.append(f"traced the card's outer edge {np.mean(offs):.1f} mm outside the first "
                             "edge found (usually the inside of the card's border)")
            else:
                warnings.append("found a possible second edge outside the card on all sides "
                                "but could not trace it; the card may be cropped too small")
        elif any(strong):
            names = ", ".join(EDGE_NAMES[i] for i in range(4) if strong[i])
            warnings.append(f"possible second edge just outside the card ({names}): border "
                            "blending into the background, a shadow, or a sleeve?")

    edges, edge_pts, edge_inl, strengths = [], [], [], []
    for i in range(4):
        if traced[i] is None:
            warnings.append(f"{EDGE_NAMES[i]} edge could not be traced; using a straight line")
            pa, pb = q[i], q[(i + 1) % 4]
            edge, pts, inl, strength = Edge(pa, pb), np.zeros((0, 2)), np.zeros(0, bool), np.zeros(1)
        else:
            edge, pts, inl, strength = traced[i]
        edges.append(edge)
        edge_pts.append(pts[inl])
        edge_inl.append((pts, inl))
        strengths.append(strength if len(strength) else np.zeros(1))

    corners = np.array([intersect(edges[i - 1], edges[i]) for i in range(4)])
    shorter_side = min(np.linalg.norm(corners[1] - corners[0]), np.linalg.norm(corners[3] - corners[0]))
    shift = np.linalg.norm(corners - q, axis=1).max()
    if not np.all(np.isfinite(corners)) or shift > 0.15 * shorter_side:
        warnings.append("fitted corners moved far from the outline's corners; "
                        "using the outline's corners")
        corners = q.copy()
    # The photo should show some table beyond every edge; if a band 4 mm outside an
    # edge falls off the photo, the card may continue past the frame.
    off = []
    for i, e in enumerate(edges):
        ppm_i = e.L / (card_w_mm if i % 2 == 0 else card_h_mm)
        band = e.point(np.linspace(0, e.L, 50)) - e.n * (4.0 * ppm_i)
        outside = ((band[:, 0] < 0) | (band[:, 1] < 0) | (band[:, 0] > w - 1) | (band[:, 1] > h - 1))
        if outside.mean() > 0.2:
            off.append(EDGE_NAMES[i])
    if off:
        warnings.append(f"card is at or past the edge of the photo ({', '.join(off)}); "
                        "it may be cropped")

    # Native output size: as many pixels as the source has along the card's height.
    native_h = max(np.linalg.norm(corners[3] - corners[0]), np.linalg.norm(corners[2] - corners[1]))
    Hr = native_h
    Wr = native_h * card_w_mm / card_h_mm
    dst = np.array([[0, 0], [Wr, 0], [Wr, Hr], [0, Hr]], np.float64)
    H = cv2.getPerspectiveTransform(corners.astype(np.float32), dst.astype(np.float32)).astype(np.float64)
    if not np.all(np.isfinite(H)) or abs(np.linalg.det(H)) < 1e-12:
        raise CardError("could not compute a perspective correction from the corners")

    bows = edge_bows(H, edge_pts, Wr, Hr)
    mm_per_px = card_h_mm / Hr
    s_grid = np.linspace(0, 1, 101)
    metrics = {"edges": {}}
    outward = []
    for i, (coef, resid, sign) in enumerate(bows):
        prof = bow_eval(coef, s_grid) * sign * mm_per_px          # + = bulges outward
        peak = float(prof[np.argmax(np.abs(prof))])
        rms = float(np.sqrt(np.mean(resid ** 2))) * mm_per_px if len(resid) else float("nan")
        pts_all, inl = edge_inl[i]
        inl_frac = float(inl.mean()) if len(inl) else 0.0
        contrast = float(np.median(strengths[i]))
        name = EDGE_NAMES[i]
        metrics["edges"][name] = {"bow_mm": peak, "scatter_mm": rms,
                                  "inliers": inl_frac, "contrast": contrast}
        if abs(peak) > WARN_BOW_MM:
            warnings.append(f"{name} edge bows {abs(peak):.2f} mm "
                            f"{'outward' if peak > 0 else 'inward'}; more than lens distortion "
                            "usually causes (possible curl, sleeve or toploader)")
        if np.isfinite(rms) and rms > WARN_RESIDUAL_MM:
            warnings.append(f"{name} edge is ragged (points scatter {rms:.2f} mm from the fit; "
                            "glare, shadow, occlusion or a sleeve edge)")
        if inl_frac < WARN_INLIER_FRAC:
            warnings.append(f"only {inl_frac:.0%} of the {name} edge could be traced")
        if contrast < WARN_EDGE_CONTRAST:
            warnings.append(f"{name} edge has low contrast against the background")
        if abs(peak) >= WARN_MIXED_BOW_MM:
            outward.append(peak > 0)
    contrasts = [m["contrast"] for m in metrics["edges"].values()]
    if max(contrasts) > 0 and min(contrasts) / max(contrasts) < WARN_CONTRAST_RATIO:
        weak = ", ".join(n for n, m in metrics["edges"].items()
                         if m["contrast"] < WARN_CONTRAST_RATIO * max(contrasts))
        warnings.append(f"{weak} edge contrast is much weaker than the others "
                        "(a shadow may have been traced as part of the card)")
    if outward and any(outward) and not all(outward):
        warnings.append("some edges bow outward and others inward, which lens distortion "
                        "does not do (possible curl or bend)")

    if native_h < NOTE_MIN_HEIGHT_PX:
        notes.append(f"low resolution: card is only about {native_h:.0f} px tall in the photo")

    Ho = int(round(height)) if height else int(round(Hr))
    Wo = int(round(Ho * card_w_mm / card_h_mm))
    rh = max(Ho, int(round(Hr)))           # render at least at native size, then shrink
    rw = int(round(rh * card_w_mm / card_h_mm))
    out = render(img, H, bows, Wr, Hr, rw, rh, bend=bend)
    if (rw, rh) != (Wo, Ho):
        out = cv2.resize(out, (Wo, Ho), interpolation=cv2.INTER_AREA)

    info = {"warnings": warnings, "notes": notes, "metrics": metrics,
            "corners": corners, "rough_corners": q, "edges": edges,
            "edge_inl": edge_inl, "native_height": native_h,
            "source": source, "outline_score": outline_score}
    return out, info


def debug_overlay(img, info):
    h, w = img.shape[:2]
    s = min(1.0, 1600 / max(h, w))
    vis = cv2.resize(img, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA) if s < 1 else img.copy()
    lw = max(1, int(round(2 * s * max(h, w) / 1600)))

    def P(p):
        return (int(round((p[0] + 0.5) * s - 0.5)), int(round((p[1] + 0.5) * s - 0.5)))

    for edge, (pts, inl) in zip(info["edges"], info["edge_inl"]):
        ts = np.linspace(-0.05 * edge.L, 1.05 * edge.L, 200)
        curve = np.array([P(edge.point(t)) for t in ts], np.int32)
        cv2.polylines(vis, [curve], False, (255, 120, 0), lw, cv2.LINE_AA)
        for p, good in zip(pts, inl):
            cv2.circle(vis, P(p), lw, (0, 200, 0) if good else (0, 0, 255), -1)
    for p in info["rough_corners"]:
        cv2.drawMarker(vis, P(p), (0, 200, 255), cv2.MARKER_TILTED_CROSS, 6 * lw, lw)
    for p in info["corners"]:
        cv2.circle(vis, P(p), 4 * lw, (0, 255, 255), lw, cv2.LINE_AA)
    return vis


# --------------------------------------------------------------------- corner picker

PICK_MAX_W, PICK_MAX_H = 1400, 900     # window size limit (the photo is scaled to fit)
PICK_LABELS = ("TL", "TR", "BR", "BL")
PICK_HELP = ("drag corners to the card's corners | click to add, right-click to remove | "
             "F flip top/bottom | A auto | R clear | Enter accept | S skip | Q quit")


class CornerPicker:
    """State and drawing for the click-the-corners window, kept separate from the
    window itself so it can be driven by any event source."""

    def __init__(self, img, initial=None, title=""):
        self.img = img
        h, w = img.shape[:2]
        self.scale = min(1.0, PICK_MAX_W / w, (PICK_MAX_H - 40) / h)
        self.view = cv2.resize(img, (int(round(w * self.scale)), int(round(h * self.scale))),
                               interpolation=cv2.INTER_AREA) if self.scale < 1 else img.copy()
        self.initial = [tuple(map(float, p)) for p in initial] if initial is not None else []
        self.pts = list(self.initial)
        self.title = title
        self.drag = None
        self.cursor = None

    def to_view(self, p):
        return ((p[0] + 0.5) * self.scale - 0.5, (p[1] + 0.5) * self.scale - 0.5)

    def to_img(self, x, y):
        h, w = self.img.shape[:2]
        return (min(max((x + 0.5) / self.scale - 0.5, 0.0), w - 1.0),
                min(max((y + 0.5) / self.scale - 0.5, 0.0), h - 1.0))

    def nearest(self, x, y, radius=14):
        best, dbest = None, radius
        for i, p in enumerate(self.pts):
            vx, vy = self.to_view(p)
            d = np.hypot(vx - x, vy - y)
            if d <= dbest:
                best, dbest = i, d
        return best

    def mouse(self, event, x, y, flags=0, param=None):
        self.cursor = (x, y)
        if event == cv2.EVENT_LBUTTONDOWN:
            i = self.nearest(x, y)
            if i is not None:
                self.drag = i
            elif len(self.pts) < 4:
                self.pts.append(self.to_img(x, y))
                self.drag = len(self.pts) - 1
        elif event == cv2.EVENT_MOUSEMOVE and self.drag is not None:
            self.pts[self.drag] = self.to_img(x, y)
        elif event == cv2.EVENT_LBUTTONUP:
            self.drag = None
        elif event == cv2.EVENT_RBUTTONDOWN and self.pts:
            i = self.nearest(x, y, radius=40)
            self.pts.pop(len(self.pts) - 1 if i is None else i)

    def key(self, k):
        """Returns 'accept', 'skip', 'quit' or None (keep going)."""
        if k in (13, 10, 32) and len(self.pts) == 4:
            return "accept"
        if k in (ord("s"), ord("S"), 27):
            return "skip"
        if k in (ord("q"), ord("Q")):
            return "quit"
        if k in (ord("r"), ord("R")):
            self.pts = []
        elif k in (ord("a"), ord("A")):
            self.pts = list(self.initial)
        elif k in (ord("f"), ord("F")) and len(self.pts) == 4:
            self.pts = self.pts[2:] + self.pts[:2]           # swap which end is the top
        return None

    def render(self):
        vh, vw = self.view.shape[:2]
        frame = np.zeros((vh + 40, max(vw, 900), 3), np.uint8)
        frame[:vh, :vw] = self.view
        lw = 2
        vpts = [tuple(int(round(c)) for c in self.to_view(p)) for p in self.pts]
        if len(vpts) >= 2:
            cv2.polylines(frame, [np.array(vpts, np.int32)], len(vpts) == 4, (0, 255, 255), lw, cv2.LINE_AA)
        if len(vpts) == 4:     # mark the top edge so the orientation is visible
            cv2.line(frame, vpts[0], vpts[1], (0, 200, 0), lw + 2, cv2.LINE_AA)
        for i, p in enumerate(vpts):
            cv2.circle(frame, p, 7, (0, 0, 255), lw, cv2.LINE_AA)
            cv2.putText(frame, PICK_LABELS[i], (p[0] + 9, p[1] - 9), cv2.FONT_HERSHEY_SIMPLEX, 0.6,
                        (0, 0, 0), 4, cv2.LINE_AA)
            cv2.putText(frame, PICK_LABELS[i], (p[0] + 9, p[1] - 9), cv2.FONT_HERSHEY_SIMPLEX, 0.6,
                        (255, 255, 255), 1, cv2.LINE_AA)
        if self.cursor is not None and self.cursor[1] < vh:
            self._loupe(frame, vw, vh)
        msg = PICK_HELP if len(self.pts) == 4 else \
            f"click the card's {('top-left', 'top-right', 'bottom-right', 'bottom-left')[len(self.pts)]} corner" \
            " (as it should appear upright) | R clear | A auto | S skip | Q quit"
        cv2.putText(frame, msg, (8, vh + 26), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (230, 230, 230), 1, cv2.LINE_AA)
        return frame

    def _loupe(self, frame, vw, vh):
        """Magnified full-resolution view under the cursor, for placing corners precisely:
        about 50 window pixels' worth of the photo, shown 200 px wide."""
        cx, cy = self.to_img(*self.cursor)
        r = int(np.clip(round(25 / self.scale), 12, 60))
        h, w = self.img.shape[:2]
        x0, y0 = int(round(cx)) - r, int(round(cy)) - r
        patch = np.zeros((2 * r + 1, 2 * r + 1, 3), np.uint8)
        sx0, sy0, sx1, sy1 = max(x0, 0), max(y0, 0), min(x0 + 2 * r + 1, w), min(y0 + 2 * r + 1, h)
        if sx1 > sx0 and sy1 > sy0:
            patch[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = self.img[sy0:sy1, sx0:sx1]
        size = 200
        big = cv2.resize(patch, (size, size), interpolation=cv2.INTER_NEAREST if r < 40 else cv2.INTER_AREA)
        c = size // 2
        cv2.line(big, (c, 0), (c, size), (0, 255, 255), 1)
        cv2.line(big, (0, c), (size, c), (0, 255, 255), 1)
        cv2.rectangle(big, (0, 0), (size - 1, size - 1), (255, 255, 255), 1)
        # Put the loupe in the corner of the window away from the cursor.
        px = 8 if self.cursor[0] > vw / 2 else vw - size - 8
        py = 8 if self.cursor[1] > vh / 2 else vh - size - 8
        if px >= 0 and py >= 0 and px + size <= frame.shape[1] and py + size <= vh:
            frame[py:py + size, px:px + size] = big


def pick_corners(img, initial=None, title="cardflat"):
    """Open a window to place the four corners. Returns ('accept', corners) or
    ('skip', None) or ('quit', None)."""
    win = f"cardflat - {title}"
    try:
        cv2.namedWindow(win, cv2.WINDOW_AUTOSIZE)
    except cv2.error:
        raise CardError("this OpenCV has no window support (opencv-python-headless, or no display); "
                        "install opencv-python, or pass the corners with --corners")
    picker = CornerPicker(img, initial, title)
    cv2.setMouseCallback(win, picker.mouse)
    result = "skip"
    shown = False
    while True:
        cv2.imshow(win, picker.render())
        k = cv2.waitKey(20)
        if shown and cv2.getWindowProperty(win, cv2.WND_PROP_VISIBLE) < 1:
            break                                    # window closed with the mouse
        shown = True
        if k >= 0:
            r = picker.key(k & 0xFF)
            if r:
                result = r
                break
    try:
        cv2.destroyWindow(win)
        cv2.waitKey(1)
    except cv2.error:
        pass
    return result, (np.array(picker.pts) if result == "accept" else None)


# ----------------------------------------------------------------------------- CLI

def parse_size(text):
    try:
        w, h = (float(v) for v in text.lower().split("x"))
        if w <= 0 or h <= 0:
            raise ValueError
        return (min(w, h), max(w, h))
    except ValueError:
        raise argparse.ArgumentTypeError("size must look like 63x88")


def parse_corners(text):
    try:
        v = [float(t) for t in text.replace(";", ",").replace(" ", ",").split(",") if t]
        if len(v) != 8:
            raise ValueError
        return np.array(v).reshape(4, 2)
    except ValueError:
        raise argparse.ArgumentTypeError("corners must be 8 numbers: x,y of top-left, top-right, "
                                         "bottom-right, bottom-left")


def corners_arg(q):
    return ",".join(f"{v:.0f}" for v in np.asarray(q).reshape(-1))


def output_path(src, args, multiple):
    stem = os.path.splitext(os.path.basename(src))[0]
    if args.output and not multiple and args.output.lower().endswith(".png"):
        return args.output
    folder = args.output or os.path.dirname(src)
    return os.path.join(folder, stem + args.suffix + ".png")


def write_image(path, image):
    ok, buf = cv2.imencode(os.path.splitext(path)[1] or ".png", image)
    if not ok:
        raise CardError(f"could not encode {path}")
    buf.tofile(path)   # works with non-ASCII paths, unlike cv2.imwrite on Windows


def report(info, verbose):
    if verbose:
        for name, m in info["metrics"]["edges"].items():
            print(f"  {name:>6}: bow {m['bow_mm']:+.2f} mm, scatter {m['scatter_mm']:.3f} mm, "
                  f"traced {m['inliers']:.0%}, contrast {m['contrast']:.0f}")
    if info["warnings"]:
        print(f"  {WARNING_TEXT}")
        for wmsg in info["warnings"]:
            print(f"    - {wmsg}")
    for note in info["notes"]:
        print(f"  note: {note}")


def process(src, args, multiple):
    """Flatten one photo. Returns 'ok', 'warned', 'skipped', 'failed' or 'quit'."""
    img = load_image(src)
    kw = dict(size_mm=args.size, height=args.height, bend=not args.no_bend)
    manual = args.corners
    out = info = None
    auto_error = None

    if manual is None:
        try:
            out, info = flatten(img, **kw)
        except CardError as e:
            auto_error = e
        wants_pick = args.pick or (args.pick_if_warned and (auto_error or info["warnings"]))
        if wants_pick:
            if auto_error:
                print(f"{src}: automatic detection failed ({auto_error}); opening the corner picker")
            elif info["warnings"]:
                print(f"{src}: automatic result has warnings; opening the corner picker")
                for wmsg in info["warnings"]:
                    print(f"    - {wmsg}")
            initial = info["corners"] if info is not None else None
            choice, picked = pick_corners(img, initial, os.path.basename(src))
            if choice == "quit":
                return "quit"
            if choice == "accept":
                manual = picked
            elif out is None or args.pick:
                print(f"{src}: skipped; nothing written")
                return "skipped"
            # skipped with --pick-if-warned: fall back to the automatic result
        elif auto_error:
            raise auto_error

    if manual is not None:
        out, info = flatten(img, corners=manual, **kw)
        info["notes"].append(f"corners used, to repeat this: --corners {corners_arg(info['rough_corners'])}")

    if not args.square:
        r = args.corner_radius * out.shape[0] / args.size[1]
        out = np.dstack([out, corner_alpha(out.shape[1], out.shape[0], r)])
    rot = {90: cv2.ROTATE_90_CLOCKWISE, 180: cv2.ROTATE_180,
           270: cv2.ROTATE_90_COUNTERCLOCKWISE}.get(args.rotate)
    if rot is not None:
        out = cv2.rotate(out, rot)
    dst = output_path(src, args, multiple)
    write_image(dst, out)
    print(f"{src} -> {dst}  ({out.shape[1]}x{out.shape[0]}, {info['source']})")
    if args.debug:
        dbg = os.path.splitext(dst)[0] + "_debug.jpg"
        write_image(dbg, debug_overlay(img, info))
        print(f"  debug overlay: {dbg}")
    report(info, args.verbose)
    return "warned" if info["warnings"] else "ok"


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Flatten photos of trading cards: remove perspective and lens "
                    "distortion using the card's outline.")
    ap.add_argument("images", nargs="+", help="photos, one card each")
    ap.add_argument("-o", "--output", help="output folder, or a .png path for a single input "
                                           "(default: next to each photo)")
    ap.add_argument("--suffix", default="_flat", help="added to output names (default: _flat)")
    ap.add_argument("--size", type=parse_size, default=DEFAULT_SIZE_MM, metavar="WxH",
                    help="card size in mm (default: 63x88)")
    ap.add_argument("--height", type=int, help="output height in px (default: the card's height "
                                               "in the photo, i.e. no upscaling)")
    ap.add_argument("--corner-radius", type=float, default=DEFAULT_CORNER_RADIUS_MM, metavar="MM",
                    help="radius of the transparent rounded corners (default: 3)")
    ap.add_argument("--square", action="store_true", help="keep square, opaque corners")
    ap.add_argument("--rotate", type=int, choices=(0, 90, 180, 270), default=0,
                    help="rotate the result clockwise by this many degrees")
    ap.add_argument("--no-bend", action="store_true",
                    help="perspective correction only; don't straighten bowed edges")
    pick = ap.add_mutually_exclusive_group()
    pick.add_argument("--pick", action="store_true",
                      help="open a window to place the four corners for every photo "
                           "(pre-filled with the automatic result when there is one)")
    pick.add_argument("--pick-if-warned", action="store_true",
                      help="open the corner window only when the automatic result has warnings "
                           "or fails")
    pick.add_argument("--corners", type=parse_corners, metavar="X,Y,...",
                      help="the card's corners in photo pixels: top-left, top-right, "
                           "bottom-right, bottom-left (single photo only); rough is fine")
    ap.add_argument("--debug", action="store_true",
                    help="also write <name>_debug.jpg showing the detected edges")
    ap.add_argument("-v", "--verbose", action="store_true", help="print per-edge measurements")
    args = ap.parse_args(argv)

    if args.corners is not None and len(args.images) > 1:
        ap.error("--corners applies to a single photo")
    if args.output and not args.output.lower().endswith(".png"):
        os.makedirs(args.output, exist_ok=True)
    multiple = len(args.images) > 1
    counts = {"ok": 0, "warned": 0, "skipped": 0, "failed": 0}

    for src in args.images:
        try:
            status = process(src, args, multiple)
        except CardError as e:
            status = "failed"
            hint = "" if args.pick or args.pick_if_warned or args.corners is not None \
                else " (try --pick to place the corners yourself)"
            print(f"{src}: ERROR: {e}; nothing written{hint}", file=sys.stderr)
        if status == "quit":
            print("quit; remaining photos not processed")
            break
        counts[status] += 1

    if multiple:
        print(f"\n{counts['ok'] + counts['warned']} flattened ({counts['warned']} with warnings), "
              f"{counts['skipped']} skipped, {counts['failed']} failed")
    return 1 if counts["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
