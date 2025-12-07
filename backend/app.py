import os
import pickle
from typing import Any, Dict, Tuple, Optional

import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from skimage import img_as_float
from skimage.color import rgb2gray
from skimage.feature import hog
from skimage.filters import gabor
from skimage.segmentation import slic

# =========================================================
# Config
# =========================================================
MODEL_PATH = os.getenv("SVM_BUNDLE_PATH", "svm_bestparams_threshold_minErr_fromVAL.pkl")

# Default fallback (akan dioverride jika ada feature_info dari bundle)
DEFAULT_IMG_SIZE = (128, 128)
DEFAULT_SLIC_N_SEGMENTS = 200
DEFAULT_SLIC_COMPACTNESS = 10
DEFAULT_SLIC_SIGMA = 1

# Optional: batasi ukuran upload agar server tidak berat (mis. 10 MB)
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(10 * 1024 * 1024)))


# =========================================================
# Load bundle
# =========================================================
bundle: Dict[str, Any] = {}
model = None
threshold: Optional[float] = None

# Feature params (bisa diambil dari bundle feature_info kalau ada)
IMG_SIZE = DEFAULT_IMG_SIZE
SLIC_N_SEGMENTS = DEFAULT_SLIC_N_SEGMENTS
SLIC_COMPACTNESS = DEFAULT_SLIC_COMPACTNESS
SLIC_SIGMA = DEFAULT_SLIC_SIGMA


def load_bundle(path: str) -> Tuple[Dict[str, Any], Any, float]:
    if not os.path.exists(path):
        raise FileNotFoundError(f"Model bundle not found at: {path}")

    with open(path, "rb") as f:
        b = pickle.load(f)

    if not isinstance(b, dict) or "model" not in b or "threshold_from_val" not in b:
        raise ValueError("Invalid bundle format. Expected dict with keys: 'model' and 'threshold_from_val'.")

    m = b["model"]
    thr = float(b["threshold_from_val"])
    return b, m, thr


def _apply_feature_info_if_any(b: Dict[str, Any]) -> None:
    """Jika bundle menyimpan info parameter, pakai itu biar konsisten."""
    global IMG_SIZE, SLIC_N_SEGMENTS, SLIC_COMPACTNESS, SLIC_SIGMA

    info = b.get("feature_info", {}) or {}

    # contoh: 'img_size': (128,128)
    if isinstance(info.get("img_size"), (tuple, list)) and len(info["img_size"]) == 2:
        IMG_SIZE = (int(info["img_size"][0]), int(info["img_size"][1]))

    # Jika kamu menyimpan parameter SLIC di feature_info di masa depan, bisa diaktifkan:
    # SLIC_N_SEGMENTS = int(info.get("slic_n_segments", SLIC_N_SEGMENTS))
    # SLIC_COMPACTNESS = float(info.get("slic_compactness", SLIC_COMPACTNESS))
    # SLIC_SIGMA = float(info.get("slic_sigma", SLIC_SIGMA))


# =========================================================
# Preprocessing + Feature extraction (SAMA seperti Colab)
# =========================================================
def decode_image_to_bgr(file_bytes: bytes) -> np.ndarray:
    """Decode bytes -> BGR image. Raise ValueError jika bukan gambar valid."""
    np_arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Cannot decode image. Make sure the uploaded file is a valid JPG/PNG.")
    return img


def slic_smooth_and_gray(
    bgr_img: np.ndarray,
    n_segments: int = SLIC_N_SEGMENTS,
    compactness: float = SLIC_COMPACTNESS,
    sigma: float = SLIC_SIGMA
) -> np.ndarray:
    rgb = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2RGB)
    rgb_f = img_as_float(rgb)

    segments = slic(
        rgb_f,
        n_segments=n_segments,
        compactness=compactness,
        sigma=sigma,
        start_label=0
    )

    out = np.zeros_like(rgb_f, dtype=np.float32)
    for seg_id in np.unique(segments):
        mask = (segments == seg_id)
        mean_color = rgb_f[mask].mean(axis=0)
        out[mask] = mean_color

    gray = rgb2gray(out).astype(np.float32)
    return gray


def hog_features(
    gray: np.ndarray,
    pixels_per_cell=(8, 8),
    cells_per_block=(2, 2),
    orientations=9
) -> np.ndarray:
    feat = hog(
        gray,
        orientations=orientations,
        pixels_per_cell=pixels_per_cell,
        cells_per_block=cells_per_block,
        block_norm="L2-Hys",
        transform_sqrt=True,
        feature_vector=True,
    )
    return feat.astype(np.float32)


def hogg_features(
    gray: np.ndarray,
    frequencies=(0.1, 0.2, 0.3),
    thetas=(0, np.pi / 4, np.pi / 2, 3 * np.pi / 4),
    pixels_per_cell=(8, 8),
    cells_per_block=(2, 2),
    orientations=9
) -> np.ndarray:
    mags = []
    for f in frequencies:
        for t in thetas:
            real, imag = gabor(gray, frequency=f, theta=t)
            mag = np.sqrt(real**2 + imag**2)
            mags.append(mag)

    mag_agg = np.mean(np.stack(mags, axis=0), axis=0).astype(np.float32)
    return hog_features(
        mag_agg,
        pixels_per_cell=pixels_per_cell,
        cells_per_block=cells_per_block,
        orientations=orientations
    )


def extract_feature_from_bgr(bgr: np.ndarray) -> np.ndarray:
    """Resize -> SLIC smooth -> gray -> HOG + HOGG -> concat"""
    bgr = cv2.resize(bgr, IMG_SIZE, interpolation=cv2.INTER_AREA)
    gray = slic_smooth_and_gray(bgr)
    f_hog = hog_features(gray)
    f_hogg = hogg_features(gray)
    return np.concatenate([f_hog, f_hogg], axis=0)


def decision_score_from_pipeline(pipeline, X_2d: np.ndarray) -> np.ndarray:
    """
    Bundle kamu pipeline: scaler -> svm
    """
    try:
        Xs = pipeline.named_steps["scaler"].transform(X_2d)
        return pipeline.named_steps["svm"].decision_function(Xs)
    except Exception as e:
        raise RuntimeError(
            "Pipeline format mismatch. Expected named_steps['scaler'] & ['svm']. "
            f"Original error: {e}"
        )


# =========================================================
# FastAPI app
# =========================================================
app = FastAPI(title="Hijab Detection API (SVM)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # untuk dev, bebas
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup():
    global bundle, model, threshold
    bundle, model, threshold = load_bundle(MODEL_PATH)
    _apply_feature_info_if_any(bundle)

    print("✅ Bundle loaded")
    print("   Threshold:", threshold)
    print("   Feature info:", bundle.get("feature_info", {}))
    print("   Using IMG_SIZE:", IMG_SIZE)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "threshold": threshold,
        "img_size": IMG_SIZE,
    }


@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    """
    multipart/form-data field:
      - file: image (jpg/png/anything) -> we decode bytes to verify
    """
    if model is None or threshold is None:
        raise HTTPException(status_code=500, detail="Model not loaded.")

    # (Opsional) limit size: hindari upload raksasa
    try:
        file_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read upload: {e}")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file.")

    if len(file_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max {MAX_UPLOAD_BYTES} bytes."
        )

    # Solusi 1: abaikan content-type, langsung decode
    try:
        bgr = decode_image_to_bgr(file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid image file: {e}")

    try:
        feat = extract_feature_from_bgr(bgr).reshape(1, -1)
        score = float(decision_score_from_pipeline(model, feat)[0])

        pred = 1 if score > float(threshold) else 0
        label = "HIJAB" if pred == 1 else "NONHIJAB"

        return {
            "label": label,
            "pred": pred,
            "score": score,
            "threshold": float(threshold),
            "margin_from_threshold": float(score - float(threshold)),
            # debug fields (boleh dihapus nanti)
            "filename": file.filename,
            "content_type": file.content_type,
            "bytes": len(file_bytes),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference failed: {e}")
