import numpy as np
import cv2
from skimage import segmentation, color, feature, filters, util, graph
from skimage.measure import regionprops
from sklearn.svm import SVC
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.model_selection import train_test_split
import random
from collections import defaultdict

def compute_slic(img, n_segments=400, compactness=15):
    img_f = util.img_as_float(img)
    labels = segmentation.slic(img_f, n_segments=n_segments, compactness=compactness, start_label=0)
    props = regionprops(labels + 1)
    return labels, props

def compute_hog(patch, pixels_per_cell=(8,8), cells_per_block=(2,2), orientations=9):
    if patch.ndim == 3:
        gray = cv2.cvtColor(patch, cv2.COLOR_RGB2GRAY)
    else:
        gray = patch
    gray = util.img_as_float(gray)
    h = feature.hog(gray, orientations=orientations, pixels_per_cell=pixels_per_cell,
            cells_per_block=cells_per_block, block_norm='L2-Hys', feature_vector=True)
    return h

def compute_gabor_responses(img, frequencies=[0.1, 0.2], thetas=[0, np.pi/4, np.pi/2, 3*np.pi/4]):
    responses = []
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY) if img.ndim==3 else img
    gray = util.img_as_float(gray)
    for freq in frequencies:
        for theta in thetas:
            kernel = cv2.getGaborKernel(ksize=(21,21), sigma=4.0, theta=theta, lambd=1.0/freq, gamma=0.5, psi=0)
            filtered = cv2.filter2D(gray, cv2.CV_32F, kernel)
            responses.append(filtered)
    return responses

def extract_superpixel_features(img, labels, props, hog_params=None, gabor_freqs=None, gabor_thetas=None):
    if hog_params is None:
        hog_params = {'pixels_per_cell': (8,8), 'cells_per_block': (2,2), 'orientations':9}
    if gabor_freqs is None:
        gabor_freqs = [0.08, 0.18]
    if gabor_thetas is None:
        gabor_thetas = [0, np.pi/4, np.pi/2, 3*np.pi/4]
    gabor_responses = compute_gabor_responses(img, frequencies=gabor_freqs, thetas=gabor_thetas)
    features = []
    meta = []
    for r in props:
        minr, minc, maxr, maxc = r.bbox
        patch = img[minr:maxr, minc:maxc]
        mask = (labels[minr:maxr, minc:maxc] == (r.label-1))
        if patch.size == 0 or mask.sum() < 10:
            features.append(np.zeros(1))
            meta.append({'bbox': r.bbox, 'centroid': r.centroid})
            continue
        try:
            hog_box = compute_hog(patch, **hog_params)
        except:
            hog_box = np.zeros(1)
        hogg_list = []
        for resp in gabor_responses:
            sub = resp[minr:maxr, minc:maxc]
            sub_masked = sub * mask
            mm = sub_masked - sub_masked.min()
            if mm.max() > 0:
                mm = mm / mm.max()
            try:
                h = feature.hog(mm, orientations=hog_params['orientations'],
                        pixels_per_cell=hog_params['pixels_per_cell'],
                        cells_per_block=hog_params['cells_per_block'], block_norm='L2-Hys', feature_vector=True)
            except:
                h = np.zeros(1)
            hogg_list.append(h)
        feat = np.concatenate([hog_box] + hogg_list)
        features.append(feat)
        meta.append({'bbox': r.bbox, 'centroid': r.centroid})
    return features, meta

class SimpleRFerns:
    def __init__(self, n_ferns=50, fern_size=11, rng_seed=42):
        self.n_ferns = n_ferns
        self.fern_size = fern_size
        self.ferns = []
        self.tables = []
        random.seed(rng_seed)
        self._trained = False

    def _make_fern(self, dim):
        tests = []
        for _ in range(self.fern_size):
            idx = random.randrange(dim)
            thr = random.random()
            tests.append((idx, thr))
        return tests

    def fit(self, X, y):
        X = np.array(X)
        mins = X.min(axis=0)
        maxs = X.max(axis=0)
        diff = (maxs - mins)
        diff[diff==0] = 1.0
        Xn = (X - mins) / diff
        self.mins = mins; self.maxs = maxs; self.diff = diff
        dim = Xn.shape[1]
        self.ferns = [self._make_fern(dim) for _ in range(self.n_ferns)]
        self.tables = []
        for fern in self.ferns:
            table_counts = defaultdict(lambda: defaultdict(int))
            for xi, yi in zip(Xn, y):
                key = 0
                for i,(idx,thr) in enumerate(fern):
                    bit = int(xi[idx] > thr)
                    key = (key << 1) | bit
                table_counts[key][yi] += 1
            table_prob = {}
            for key,cls_counts in table_counts.items():
                total = sum(cls_counts.values())
                probs = {cls: cls_counts[cls]/total for cls in cls_counts}
                table_prob[key] = probs
            self.tables.append(table_prob)
        self._trained = True

    def predict_proba(self, X):
        X = np.array(X)
        Xn = (X - self.mins) / self.diff
        results = []
        for xi in Xn:
            class_logprob = defaultdict(float)
            for fern, table in zip(self.ferns, self.tables):
                key = 0
                for (idx,thr) in fern:
                    bit = int(xi[idx] > thr)
                    key = (key << 1) | bit
                probs = table.get(key, None)
                if probs is None:
                    continue
                for cls,p in probs.items():
                    class_logprob[cls] += np.log(p + 1e-9)
            if len(class_logprob)==0:
                results.append({})
                continue
            maxlog = max(class_logprob.values())
            expd = {cls: np.exp(lp - maxlog) for cls,lp in class_logprob.items()}
            s = sum(expd.values())
            probs = {cls: expd[cls]/s for cls in expd}
            results.append(probs)
        return results

def pad_features(features, target_len=1024):
    padded = []
    for f in features:
        if f.size == 0:
            padded.append(np.zeros(target_len))
        else:
            if f.size >= target_len:
                padded.append(f[:target_len])
            else:
                arr = np.zeros(target_len)
                arr[:f.size] = f
                padded.append(arr)
    return np.array(padded)

def demo_train_svm(features, labels):
    X = pad_features(features, target_len=1024)
    X_train, X_test, y_train, y_test = train_test_split(X, labels, test_size=0.2, random_state=42)
    clf = make_pipeline(StandardScaler(), SVC(probability=True, kernel='linear'))
    clf.fit(X_train, y_train)
    return clf

def self_train_on_image(features, labels_hint):
    rf = SimpleRFerns(n_ferns=40, fern_size=8)
    rf.fit(pad_features(features, target_len=1024), labels_hint)
    return rf

def infer_superpixels(features, self_rf, svm_clf, rfern_conf_threshold=0.7):
    Xp = pad_features(features, target_len=1024)
    rf_probs = self_rf.predict_proba(Xp)
    preds = []
    for i, probs in enumerate(rf_probs):
        if not probs:
            p = svm_clf.predict_proba([Xp[i]])[0]
            label = svm_clf.classes_[np.argmax(p)]
            conf = max(p)
        else:
            cls, conf = max(probs.items(), key=lambda kv: kv[1])
            label = cls if conf >= rfern_conf_threshold else None
            if label is None:
                p = svm_clf.predict_proba([Xp[i]])[0]
                label = svm_clf.classes_[np.argmax(p)]
                conf = max(p)
        preds.append((label, conf))
    return preds

def build_adjacency_graph(labels):
    img_dummy = color.label2rgb(labels, bg_label=0)
    rag = graph.rag_mean_color(img_dummy, labels)
    adj = {n: set() for n in rag.nodes}
    for u,v,data in rag.edges(data=True):
        adj[u].add(v); adj[v].add(u)
    return adj

def aggregate_region_growing(labels, features, meta, preds, similarity_thresh=0.6):
    adj = build_adjacency_graph(labels)
    n = len(preds)
    beard_indices = [i for i,(lab,_) in enumerate(preds) if lab==1]
    visited = set()
    groups = []
    Pf = pad_features(features, target_len=1024)
    for idx in beard_indices:
        if idx in visited: continue
        q = [idx]; group = set([idx]); visited.add(idx)
        while q:
            cur = q.pop(0)
            neighbors = adj.get(cur, set())
            for nb in neighbors:
                nb_idx = nb
                if nb_idx<0 or nb_idx>=n: continue
                if nb_idx in visited: continue
                a = Pf[cur]; b = Pf[nb_idx]
                denom = (np.linalg.norm(a)*np.linalg.norm(b)+1e-9)
                sim = np.dot(a,b)/denom
                if sim >= similarity_thresh:
                    visited.add(nb_idx); q.append(nb_idx); group.add(nb_idx)
        groups.append(sorted(list(group)))
    return groups

def detect_face_simple(img):
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
    if len(faces) == 0:
        print('No face detected.')
        return None
    (x, y, w, h) = faces[0]
    turun_pixel = int(h * 0.60)
    y_baru = y + turun_pixel
    padding_bawah = int(h * 0.10)
    y_akhir = y + h + padding_bawah
    if y_akhir > img.shape[0]: y_akhir = img.shape[0]
    face_crop = img[y_baru : y_akhir, x : x+w]
    return face_crop

def main_facial_hair_detection(image_data):
    img = image_data
    if img is None:
        print('[ERROR] Image is None.')
        return None, None
    H, W = img.shape[:2]
    labels, props = compute_slic(img, n_segments=450, compactness=7)
    n_sp = len(props)
    feats, meta = extract_superpixel_features(img, labels, props)
    hints = np.zeros(n_sp, dtype=int)
    for i, r in enumerate(props):
        cy, cx = r.centroid
        cy = int(cy); cx = int(cx)
        sp_intensity = img[cy, cx].mean()
        if cy < H * 0.40:
            hints[i] = 0
            continue
        if cy > H * 0.65:
            if sp_intensity < 120:
                hints[i] = 1
                continue
        padded_feat_i = pad_features([feats[i]], target_len=2048)[0]
        tex_strength = np.std(padded_feat_i[-50:])
        if tex_strength > 0.30 and sp_intensity < 160 and cy > H * 0.50:
            hints[i] = 1
        else:
            hints[i] = 2
    rferns = self_train_on_image(feats, hints)
    confident_mask = (hints != 2)
    filtered_feats = [feats[i] for i, confident in enumerate(confident_mask) if confident]
    filtered_hints = hints[confident_mask]
    svm_clf = demo_train_svm(filtered_feats, filtered_hints)
    preds = infer_superpixels(feats, rferns, svm_clf, rfern_conf_threshold=0.9)
    groups = aggregate_region_growing(labels, feats, meta, preds, similarity_thresh=0.55)
    final_groups = []
    for g in groups:
        confs = [preds[i][1] for i in g if preds[i][0] == 1]
        if len(confs) > 0 and np.mean(confs) > 0.55:
            final_groups.append(g)
    beard_mask = np.zeros(labels.shape, dtype=bool)
    for group in final_groups:
        for sp_idx in group:
            if preds[sp_idx][0] == 1:
                beard_mask[labels == sp_idx] = True
    overlay = np.zeros_like(img)
    overlay[beard_mask] = [0, 255, 0]
    alpha = 0.45
    result = cv2.addWeighted(img, 1 - alpha, overlay, alpha, 0)
    return result, beard_mask
