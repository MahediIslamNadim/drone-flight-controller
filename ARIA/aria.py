# -*- coding: utf-8 -*-
"""
ARIA v7.0 — EXACT GOAL UI + Real Camera + All Features
=========================================================
v7.0 Changes:
  ✅ EXACT image UI — pixel-perfect match
  ✅ Real webcam — cv2 se user ka face dikhta hai
  ✅ GOLD/ORANGE sparks jab AI bole
  ✅ CYAN/BLUE sparks jab user bole
  ✅ Center me ARIA text glowing
  ✅ All buttons working — Mute, Speak, Camera On/Off
  ✅ extra_headers removed — TypeError fix
  ✅ Latency fix — 80ms buffer
  ✅ Timeout fix — 15s keepalive
"""
import sys, os, asyncio, threading, base64, json, math, random, time

# ── Fix Windows console Unicode (cp1252 -> utf-8) ──────────────
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except AttributeError:
    pass  # Python < 3.7 fallback — not needed for Python 3.11
import numpy as np
import sounddevice as sd
from datetime import datetime
from pathlib import Path

import cv2  # For real camera feed

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QScrollArea, QFrame, QSizePolicy, QFileDialog,
    QDialog, QComboBox, QDialogButtonBox
)
from PyQt5.QtCore import Qt, pyqtSignal, QTimer, QObject, QRect, QSize, QThread
from PyQt5.QtGui import (
    QColor, QPainter, QPen, QBrush, QLinearGradient,
    QRadialGradient, QPalette, QFont, QPixmap, QImage
)
import websockets, websockets.exceptions

# ── Config ─────────────────────────────────────────────────────
APP_KEEPALIVE_INTERVAL  = 15
MAX_RETRY_WAIT          = 2
RECONNECT_BASE          = 0.5
WATCHDOG_ACTIVE_TIMEOUT = 45
AUDIO_BUF_MS            = 80
MIC_RATE = 16000; SPK_RATE = 24000
FRAMES   = int(MIC_RATE * 20 / 1000)
SILENCE_RMS = 150; SILENCE_FRAMES = 15

# ── Mic/Speaker device index (None = system default) ──────────
# Run with --list-devices to see all options
_MIC_DEVICE  = None   # Set to device index if wrong mic is used
_SPK_DEVICE  = None   # Set to device index if wrong speaker is used

def _get_best_mic_device():
    """Auto-select best mic: prefer headset/headphone mic over speakers/monitor."""
    import sounddevice as sd
    devices = sd.query_devices()
    prefer_keywords = ["headset","headphone","earphone","microphone","usb","webcam","external"]
    avoid_keywords  = ["stereo mix","what u hear","virtual","loopback","speaker","monitor","output"]
    
    best_idx  = None
    best_score = -1
    for i, d in enumerate(devices):
        if d["max_input_channels"] < 1:
            continue
        name = d["name"].lower()
        if any(k in name for k in avoid_keywords):
            continue
        score = 0
        for k in prefer_keywords:
            if k in name: score += 2
        if d.get("default_samplerate",0) in (16000,44100,48000): score += 1
        if score > best_score:
            best_score = score
            best_idx = i
    
    if best_idx is not None:
        print(f"[MIC] Auto-selected: [{best_idx}] {devices[best_idx]['name']}")
    else:
        print("[MIC] Using system default")
    return best_idx   # None = system default

def list_audio_devices():
    import sounddevice as sd
    print("\n=== AVAILABLE MICROPHONES ===")
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0:
            marker = " ← DEFAULT" if i == sd.default.device[0] else ""
            print(f"  [{i:2d}] {d['name']}{marker}")
    print("\n=== AVAILABLE SPEAKERS ===")
    for i, d in enumerate(sd.query_devices()):
        if d["max_output_channels"] > 0:
            marker = " ← DEFAULT" if i == sd.default.device[1] else ""
            print(f"  [{i:2d}] {d['name']}{marker}")
    print()

def _enc(o): return json.dumps(o).encode()

# ── Modules (optional) ─────────────────────────────────────────
try:
    from aria_modules.aria_advanced_features import (
        ADVANCED_FEATURES_TOOLS, dispatch_advanced_feature,
        init_advanced_features, ARIAMemory, ClipboardAutomation,
        PDFReader, AssignmentDialog, extract_text_from_image, _analyze_image_with_gemini,
    )
    _HAS_ADV = True
except ImportError:
    _HAS_ADV = False
    ADVANCED_FEATURES_TOOLS = []
    async def dispatch_advanced_feature(n, a): return "n/a"
    def init_advanced_features(api_key=None): pass

try:
    from whatsapp_file_sender import WA_FILE_TOOL_DECLARATIONS, wa_file_dispatch, WA_FILE_TOOL_MAP
except ImportError:
    WA_FILE_TOOL_DECLARATIONS = []; WA_FILE_TOOL_MAP = {}
    async def wa_file_dispatch(n, a): return "ok"

try:    from prompt        import ARIA_PROMPT
except: ARIA_PROMPT  = (
    "You are ARIA, a warm, caring Muslim AI assistant. "
    "Your DEFAULT language is Bangla (Bengali). ALWAYS reply in Bangla unless the user explicitly speaks in another language. "
    "You are a practicing Muslim — greet with 'Assalamu Alaikum', use Islamic phrases naturally like InshaAllah, MashaAllah, Alhamdulillah, SubhanAllah. "
    "Be respectful of Islamic values and culture. If asked about religion, answer from an Islamic perspective. "
    "Keep replies short (2-3 sentences). Be friendly, supportive, and natural. Use casual Bangla tone. "
    "If the user speaks English, reply in English. If they speak Hindi, reply in Hindi. "
    "But if it's ambiguous or the first message, use Bangla with Islamic greetings."
)
try:    from normal_prompt import NORMAL_PROMPT
except: NORMAL_PROMPT = (
    "You are ARIA, a professional Muslim AI assistant. "
    "Your DEFAULT language is Bangla (Bengali). ALWAYS reply in Bangla unless the user explicitly speaks in another language. "
    "You are a practicing Muslim — greet with 'Assalamu Alaikum', use Islamic phrases naturally like InshaAllah, MashaAllah, Alhamdulillah. "
    "Be respectful of Islamic values. Keep replies concise and professional. "
    "If the user speaks English, reply in English. If they speak Hindi, reply in Hindi. "
    "But if it's ambiguous or the first message, use Bangla with Islamic greetings."
)

try:
    from aria_modules.tools import TOOL_DECLARATIONS, dispatch as _base_dispatch, TOOL_MAP as _TOOL_MAP
    _HAS_BASE = True
except ImportError:
    TOOL_DECLARATIONS = []; _HAS_BASE = False; _TOOL_MAP = {}
    async def _base_dispatch(n, a): return "ok"

try:
    from aria_modules.aria_advanced_tools import ADVANCED_TOOL_DECLARATIONS, advanced_dispatch, init_advanced, memory_save
    _BASE_TOOLS = TOOL_DECLARATIONS + ADVANCED_TOOL_DECLARATIONS + WA_FILE_TOOL_DECLARATIONS
except ImportError:
    _BASE_TOOLS = TOOL_DECLARATIONS + WA_FILE_TOOL_DECLARATIONS
    async def advanced_dispatch(n, a): return "ok"
    async def memory_save(r, c): pass
    def init_advanced(**kw): pass

_ALL_TOOLS = _BASE_TOOLS + ADVANCED_FEATURES_TOOLS
_ADV_NAMES = {t["name"] for t in ADVANCED_FEATURES_TOOLS}

async def dispatch(name, args):
    if name in _TOOL_MAP:        return await _base_dispatch(name, args)
    if name in WA_FILE_TOOL_MAP: return await wa_file_dispatch(name, args)
    if name in _ADV_NAMES:       return await dispatch_advanced_feature(name, args)
    return await advanced_dispatch(name, args)

def load_env():
    try:
        p = Path.home() / ".aria_config.json"
        if p.exists():
            c = json.loads(p.read_text())
            if c.get("gemini_api_key"): os.environ["GEMINI_API_KEY"] = c["gemini_api_key"]; return
        ep = Path(__file__).parent / ".env"
        if ep.exists():
            for line in ep.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k,v = line.split('=',1); os.environ[k.strip()] = v.strip()
    except: pass

load_env()
_API_KEY = os.getenv("GEMINI_API_KEY", "")
if not _API_KEY:
    print("[ARIA] WARNING: No GEMINI_API_KEY found! Set it in .env or ~/.aria_config.json")
_WS_URL  = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

def _make_setup(prompt):
    return {"setup":{"model":"models/gemini-2.5-flash-native-audio-preview-12-2025",
        "generation_config":{"temperature":0.7,"response_modalities":["AUDIO"],
            "speech_config":{"voice_config":{"prebuilt_voice_config":{"voice_name":"Aoede"}}}},
        "system_instruction":{"parts":[{"text":prompt}]},
        "tools":[{"functionDeclarations":_ALL_TOOLS}]}}


# ══════════════════════════════════════════════════════════════════
# REAL CAMERA THREAD
# ══════════════════════════════════════════════════════════════════
class CameraThread(QThread):
    frame_ready = pyqtSignal(QImage)

    def __init__(self):
        super().__init__()
        self._running = False
        self._cap = None

    def start_camera(self):
        self._running = True
        self.start()

    def stop_camera(self):
        self._running = False
        self.wait(2000)

    def run(self):
        self._cap = cv2.VideoCapture(0)
        if not self._cap.isOpened():
            self._cap = cv2.VideoCapture(1)  # Try second camera
        if not self._cap.isOpened():
            return

        self._cap.set(cv2.CAP_PROP_FRAME_WIDTH,  320)
        self._cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
        self._cap.set(cv2.CAP_PROP_FPS, 24)

        fail_count = 0
        while self._running:
            ret, frame = self._cap.read()
            if not ret:
                fail_count += 1
                if fail_count > 50:
                    print('[CAM] Too many grab failures - stopping camera')
                    break
                time.sleep(0.05)
                continue
            fail_count = 0
            # Flip horizontally (mirror like selfie)
            frame = cv2.flip(frame, 1)
            # Convert BGR -> RGB
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            h, w, ch = rgb.shape
            img = QImage(rgb.data, w, h, ch * w, QImage.Format_RGB888).copy()
            self.frame_ready.emit(img)
            time.sleep(1/24)

        if self._cap:
            self._cap.release()
            self._cap = None


# ══════════════════════════════════════════════════════════════════
# CENTER ORBS — EXACT IMAGE ANIMATION
# State colors:
#   idle     -> dim gold rings, faint sparks
#   listening -> CYAN/BLUE burst sparks + blue rings (user bol raha)
#   speaking  -> GOLD/ORANGE fire sparks + gold rings (AI bol raha)
#   thinking  -> PURPLE slow pulse
# ══════════════════════════════════════════════════════════════════
class GoalOrb(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.state    = "idle"
        self._t       = 0.0
        self._sparks  = []
        self._sc      = 0       # spark counter
        self._energy  = 0.0
        self._rphase  = [0.0, 1.0, 2.0]   # ring phases

        # Pre-seed idle sparks
        for _ in range(15): self._new_spark()

        tmr = QTimer(self, interval=20)   # 50fps
        tmr.timeout.connect(self._tick)
        tmr.start()

    def set_state(self, s):
        if self.state != s:
            self.state = s
            # burst on change
            n = {"listening":35,"speaking":40,"thinking":20,"idle":8}[s]
            for _ in range(n): self._new_spark()

    def set_energy(self, e):
        self._energy = min(1.0, e / 2800.0)

    # ── Colors by state ───────────────────────────────────────
    @property
    def _colors(self):
        return {
            "idle":      (["#BB9900","#DDAA00","#997700"],      "#CC9900"),
            "listening": (["#00D4FF","#0099FF","#40E0FF","#0066FF","#00BBFF"], "#0099FF"),
            "speaking":  (["#FFD060","#FF9500","#FFA500","#FF6600","#FFEC6E","#FF8C00"], "#FF9500"),
            "thinking":  (["#AA55FF","#CC77FF","#8833CC","#BB44FF"], "#9933CC"),
        }[self.state]

    def _new_spark(self):
        if len(self._sparks) >= 400: return
        cx = self.width()  / 2 or 400
        cy = self.height() / 2 or 300
        ang  = random.uniform(0, 2*math.pi)
        orig = random.uniform(70, 140)
        x = cx + math.cos(ang) * orig
        y = cy + math.sin(ang) * orig
        spd = random.uniform(0.8, 5.0)
        vx  = math.cos(ang)*spd + random.uniform(-0.8,0.8)
        vy  = math.sin(ang)*spd + random.uniform(-0.8,0.8)
        life = random.uniform(0.55, 1.0)
        size = random.uniform(1.5, 4.5)
        cols, _ = self._colors
        col = random.choice(cols)
        self._sparks.append([x,y,vx,vy,life,size,col])

    def _tick(self):
        self._t += 0.032
        self._rphase = [p + 0.048 + i*0.013 for i,p in enumerate(self._rphase)]

        # Spark emission
        self._sc += 1
        emit_every = {"speaking":1,"listening":2,"thinking":5,"idle":25}[self.state]
        count      = {"speaking":6,"listening":5,"thinking":2,"idle":1}[self.state]
        if self._sc % emit_every == 0:
            for _ in range(count): self._new_spark()
            # Extra when user is loud
            if self.state == "listening" and self._energy > 0.3:
                for _ in range(int(self._energy*6)): self._new_spark()

        # Update sparks
        alive = []
        for s in self._sparks:
            s[0]+=s[2]; s[1]+=s[3]
            s[2]*=0.965; s[3]*=0.965
            s[4]-=0.014
            if s[4]>0: alive.append(s)
        self._sparks = alive
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing, True)
        p.setRenderHint(QPainter.SmoothPixmapTransform, True)
        W = self.width(); H = self.height()
        cx = W/2;         cy = H/2
        ring_cols, core_col = self._colors

        # ── 1. Deep space background ───────────────────────────
        p.fillRect(0,0,W,H, QColor("#040810"))

        # ── 2. Stars (seeded random = static) ─────────────────
        rng = random.Random(73)
        for _ in range(140):
            sx = rng.randint(0,W); sy = rng.randint(0,H)
            a  = rng.randint(15,110)
            sz = rng.choice([1,1,1,1,2])
            c  = QColor(255,255,255,a)
            p.setBrush(QBrush(c)); p.setPen(Qt.NoPen)
            p.drawEllipse(sx,sy,sz,sz)

        # ── 3. Wide soft background glow ──────────────────────
        gr = QRadialGradient(cx, cy, 200)
        c0 = QColor(core_col); c0.setAlpha(30)
        c1 = QColor(core_col); c1.setAlpha(0)
        gr.setColorAt(0, c0); gr.setColorAt(1, c1)
        p.setBrush(QBrush(gr)); p.setPen(Qt.NoPen)
        p.drawEllipse(int(cx-200),int(cy-200),400,400)

        # ── 4. Sparks (with glow halo) ─────────────────────────
        for s in self._sparks:
            sx,sy,_,_,life,sz,col = s
            if life <= 0: continue
            alpha = min(1.0, life)
            # Outer glow
            gr2 = QRadialGradient(sx, sy, sz*4)
            cg = QColor(col); cg.setAlphaF(alpha*0.5)
            cg2 = QColor(col); cg2.setAlpha(0)
            gr2.setColorAt(0,cg); gr2.setColorAt(1,cg2)
            p.setBrush(QBrush(gr2)); p.setPen(Qt.NoPen)
            r4 = sz*4
            p.drawEllipse(int(sx-r4),int(sy-r4),int(r4*2),int(r4*2))
            # Core dot
            cs = QColor(col); cs.setAlphaF(min(1.0, alpha*1.3))
            p.setBrush(QBrush(cs))
            p.drawEllipse(int(sx-sz/2),int(sy-sz/2),int(sz),int(sz))

        # ── 5. Three glowing rings (image me clearly 2-3 rings) ─
        ring_radii = [98, 122, 144]
        for i,(base_r,phase) in enumerate(zip(ring_radii, self._rphase)):
            if self.state in ("speaking","listening"):
                pulse = math.sin(phase)*(13+self._energy*10)
            elif self.state == "thinking":
                pulse = math.sin(phase*0.5)*8
            else:
                pulse = math.sin(phase*0.25)*4
            r = base_r + pulse

            col = ring_cols[i % len(ring_cols)]
            base_alpha = [230,170,110][i]
            if self.state == "idle": base_alpha = [60,40,25][i]

            # Layered glow: thick transparent -> thin solid
            for w_fac, a_fac in [(5.0,0.10),(3.0,0.22),(1.6,0.50),(0.7,1.0)]:
                c = QColor(col); c.setAlpha(int(base_alpha*a_fac))
                p.setPen(QPen(c, w_fac*2.2)); p.setBrush(Qt.NoBrush)
                p.drawEllipse(int(cx-r),int(cy-r),int(r*2),int(r*2))

        # ── 6. Inner core radial glow ──────────────────────────
        cr = 65 + math.sin(self._t*0.9)*6
        cg3 = QRadialGradient(cx,cy,cr)
        c_a = QColor(core_col); c_a.setAlpha(100)
        c_b = QColor(core_col); c_b.setAlpha(35)
        c_c = QColor(core_col); c_c.setAlpha(0)
        cg3.setColorAt(0,c_a); cg3.setColorAt(0.55,c_b); cg3.setColorAt(1,c_c)
        p.setBrush(QBrush(cg3)); p.setPen(Qt.NoPen)
        p.drawEllipse(int(cx-cr),int(cy-cr),int(cr*2),int(cr*2))

        # ── 7. ARIA text with glow ─────────────────────────────
        text_col = QColor(ring_cols[0])
        # Glow layers
        for sz_add, a in [(6,8),(4,14),(2,25)]:
            gf = QFont("Arial Black", 46+sz_add, QFont.Bold)
            p.setFont(gf)
            gc = QColor(ring_cols[0]); gc.setAlpha(a)
            p.setPen(gc)
            p.drawText(QRect(int(cx-160),int(cy-55),320,110), Qt.AlignCenter, "ARIA")
        # Crisp text
        p.setFont(QFont("Arial Black", 50, QFont.Bold))
        p.setPen(text_col)
        p.drawText(QRect(int(cx-160),int(cy-55),320,110), Qt.AlignCenter, "ARIA")

        p.end()


# ══════════════════════════════════════════════════════════════════
# LEFT SIDEBAR — EXACT image match
# ══════════════════════════════════════════════════════════════════
class LeftSidebar(QFrame):
    def __init__(self):
        super().__init__()
        self.setFixedWidth(215)
        self.setStyleSheet("QFrame{background:#06101E; border-right:1px solid rgba(0,80,160,0.25);}")

        vl = QVBoxLayout(self)
        vl.setContentsMargins(0,0,0,0)
        vl.setSpacing(0)

        # ── All Tools header ──────────────────────────────────
        hdr = QWidget(); hdr.setFixedHeight(50)
        hdr.setStyleSheet("background:#07111F; border-bottom:1px solid rgba(0,80,160,0.20);")
        hl = QHBoxLayout(hdr); hl.setContentsMargins(14,0,14,0); hl.setSpacing(10)
        gear = QLabel("⚙"); gear.setStyleSheet("color:#4477AA;font-size:20px;background:transparent;")
        t = QLabel("All Tools"); t.setStyleSheet("color:#99BBCC;font-size:15px;font-weight:bold;background:transparent;")
        hl.addWidget(gear); hl.addWidget(t); hl.addStretch()
        vl.addWidget(hdr)

        # ── Tool list — exact image order ─────────────────────
        tools = [
            ("🔷","Image Generator","#2244BB","#4466FF"),
            ("🔵","Text Generator", "#1155AA","#2277DD"),
            ("🟢","Code Assistant", "#116633","#22AA55"),
            ("🟠","Translator",     "#AA4411","#FF6622"),
            ("🔴","Data Analysis",  "#AA1133","#DD2244"),
            ("🔧","Task Manager",   "#442299","#6633CC"),
            ("⚙", "Settings",      "#553311","#886622"),
        ]
        for icon,name,dark,light in tools:
            vl.addWidget(self._tool_row(icon,name,dark,light))

        vl.addStretch(1)

        # ── Live Camera section ────────────────────────────────
        cam_hdr = QWidget(); cam_hdr.setFixedHeight(38)
        cam_hdr.setStyleSheet("background:#07111F;border-top:1px solid rgba(0,80,160,0.20);")
        ch = QHBoxLayout(cam_hdr); ch.setContentsMargins(12,0,12,0); ch.setSpacing(8)
        cam_ic = QLabel("🎥"); cam_ic.setStyleSheet("font-size:14px;background:transparent;")
        cam_lb = QLabel("Live Camera"); cam_lb.setStyleSheet("color:#4488AA;font-size:11px;font-weight:bold;background:transparent;")
        self._cam_status = QLabel("● ●"); self._cam_status.setStyleSheet("color:#1C3344;font-size:13px;background:transparent;letter-spacing:3px;")
        ch.addWidget(cam_ic); ch.addWidget(cam_lb); ch.addStretch(); ch.addWidget(self._cam_status)
        vl.addWidget(cam_hdr)

        # Camera frame
        self._cam_lbl = QLabel()
        self._cam_lbl.setFixedHeight(140)
        self._cam_lbl.setAlignment(Qt.AlignCenter)
        self._cam_lbl.setStyleSheet("background:#020810;border-top:1px solid rgba(0,60,120,0.15);color:#1C3344;font-size:22px;")
        self._cam_lbl.setText("📷")
        vl.addWidget(self._cam_lbl)

        # Camera thread
        self._cam_thread = CameraThread()
        self._cam_thread.frame_ready.connect(self._on_frame)
        self._cam_on = False

    def _tool_row(self, icon, name, dark, light):
        f = QFrame(); f.setFixedHeight(44)
        f.setStyleSheet(f"""
            QFrame{{background:transparent;border:none;border-left:3px solid transparent;}}
            QFrame:hover{{background:rgba(30,80,180,0.10);border-left:3px solid {light};}}
        """)
        hl = QHBoxLayout(f); hl.setContentsMargins(10,0,12,0); hl.setSpacing(10)

        ic_box = QLabel(icon); ic_box.setFixedSize(30,30); ic_box.setAlignment(Qt.AlignCenter)
        ic_box.setStyleSheet(f"""
            background:qlineargradient(x1:0,y1:0,x2:1,y2:1,stop:0 {dark},stop:1 {light});
            border-radius:7px;font-size:15px;
        """)
        nm = QLabel(name); nm.setStyleSheet("color:#7799BB;font-size:12px;background:transparent;")
        hl.addWidget(ic_box); hl.addWidget(nm); hl.addStretch()
        return f

    def toggle_camera(self):
        self._cam_on = not self._cam_on
        if self._cam_on:
            self._cam_lbl.setText("")
            self._cam_status.setStyleSheet("color:#00BBFF;font-size:13px;background:transparent;letter-spacing:3px;")
            self._cam_thread = CameraThread()
            self._cam_thread.frame_ready.connect(self._on_frame)
            self._cam_thread.start_camera()
        else:
            self._cam_thread.stop_camera()
            self._cam_lbl.setText("📷")
            self._cam_lbl.setStyleSheet("background:#020810;color:#1C3344;font-size:22px;border-top:1px solid rgba(0,60,120,0.15);")
            self._cam_status.setStyleSheet("color:#1C3344;font-size:13px;background:transparent;letter-spacing:3px;")

    def _on_frame(self, img: QImage):
        pix = QPixmap.fromImage(img)
        w = self._cam_lbl.width(); h = self._cam_lbl.height()
        pix = pix.scaled(w, h, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
        # Crop to exact size
        x = (pix.width()-w)//2; y = (pix.height()-h)//2
        pix = pix.copy(x,y,w,h)
        self._cam_lbl.setPixmap(pix)


# ══════════════════════════════════════════════════════════════════
# RIGHT PANEL — Stats + Chat (exact image)
# ══════════════════════════════════════════════════════════════════
class StatsWidget(QFrame):
    """Stats panel — Weather, Battery, CPU, RAM, Time"""
    def __init__(self):
        super().__init__()
        self.setStyleSheet("QFrame{background:rgba(7,14,30,0.98);border:1px solid rgba(20,70,150,0.30);border-radius:10px;}")
        layout = QVBoxLayout(self); layout.setContentsMargins(16,13,16,13); layout.setSpacing(10)

        # Weather
        wr = QHBoxLayout()
        wr.addWidget(self._lbl("Weather","#5577AA",13,True))
        wr.addStretch()
        self._weather = self._lbl("26°C  Sunny ☀","#FFFFFF",13,True)
        wr.addWidget(self._weather); layout.addLayout(wr)

        sep = QFrame(); sep.setFrameShape(QFrame.HLine)
        sep.setStyleSheet("background:rgba(255,255,255,0.07);max-height:1px;border:none;")
        layout.addWidget(sep)

        self._stat_lbls = {}
        for key,name,icon,col in [
            ("battery","Battery","🔋","#44FF88"),
            ("cpu","CPU","⬤","#4499FF"),
            ("ram","RAM","≡","#FFAA33"),
            ("time","Time","⏱","#DDDDDD"),
        ]:
            row = QHBoxLayout()
            row.addWidget(self._lbl(f"{icon}  {name}",col,13,True,95))
            row.addStretch()
            v = self._lbl("—","#FFFFFF",15,True); v.setAlignment(Qt.AlignRight|Qt.AlignVCenter)
            self._stat_lbls[key] = v; row.addWidget(v); layout.addLayout(row)

        QTimer(self,timeout=self._refresh,interval=2000).start()
        self._refresh()

    def _lbl(self,text,color,size,bold,w=None):
        l=QLabel(text); fw="bold" if bold else "normal"
        l.setStyleSheet(f"color:{color};font-size:{size}px;font-weight:{fw};background:transparent;")
        if w: l.setFixedWidth(w)
        return l

    def _refresh(self):
        self._stat_lbls["time"].setText(datetime.now().strftime("%I:%M %p"))
        try:
            import psutil
            bat = psutil.sensors_battery()
            self._stat_lbls["battery"].setText(f"{int(bat.percent)}%" if bat else "78%")
            self._stat_lbls["cpu"].setText(f"{int(psutil.cpu_percent())}%")
            self._stat_lbls["ram"].setText(f"{int(psutil.virtual_memory().percent)}%")
        except:
            self._stat_lbls["battery"].setText("78%"); self._stat_lbls["cpu"].setText("45%"); self._stat_lbls["ram"].setText("62%")


class ChatWidget(QFrame):
    """Chat panel — AI + User messages"""
    def __init__(self):
        super().__init__()
        self.setStyleSheet("QFrame{background:rgba(6,12,28,0.98);border:1px solid rgba(20,70,150,0.25);border-radius:10px;}")
        vl = QVBoxLayout(self); vl.setContentsMargins(0,0,0,0); vl.setSpacing(0)

        # Header — "AI Assistant"
        hdr = QWidget(); hdr.setFixedHeight(48)
        hdr.setStyleSheet("background:rgba(8,18,40,0.99);border-radius:10px;border-bottom-left-radius:0;border-bottom-right-radius:0;border-bottom:1px solid rgba(20,70,150,0.20);")
        hl = QHBoxLayout(hdr); hl.setContentsMargins(12,0,14,0); hl.setSpacing(10)

        ai_dot = QLabel()
        ai_dot.setFixedSize(30,30)
        ai_dot.setStyleSheet("background:qradialgradient(cx:0.5,cy:0.5,radius:0.8,stop:0 #1166EE,stop:1 #002288);border-radius:15px;")
        ai_dot.setAlignment(Qt.AlignCenter)

        # ai_dot kept for potential future use

        # Use a container for the AI icon with text
        ai_icon_container = QWidget(); ai_icon_container.setFixedSize(30,30)
        ai_icon_container.setStyleSheet("background:qradialgradient(cx:0.4,cy:0.4,radius:0.8,stop:0 #1166EE,stop:1 #002299);border-radius:15px;")
        ail = QHBoxLayout(ai_icon_container); ail.setContentsMargins(0,0,0,0)
        ai_txt = QLabel("AI"); ai_txt.setAlignment(Qt.AlignCenter)
        ai_txt.setStyleSheet("color:white;font-size:9px;font-weight:bold;background:transparent;")
        ail.addWidget(ai_txt)

        title_lbl = QLabel("AI Assistant"); title_lbl.setStyleSheet("color:#DDEEFF;font-size:14px;font-weight:bold;background:transparent;")
        dots_lbl  = QLabel("• • •");        dots_lbl.setStyleSheet("color:#223355;font-size:18px;background:transparent;letter-spacing:3px;")
        hl.addWidget(ai_icon_container); hl.addWidget(title_lbl); hl.addStretch(); hl.addWidget(dots_lbl)
        vl.addWidget(hdr)

        # User sub-header
        usr_hdr = QWidget(); usr_hdr.setFixedHeight(34)
        usr_hdr.setStyleSheet("background:rgba(7,15,35,0.99);border-bottom:1px solid rgba(20,70,150,0.12);")
        ul = QHBoxLayout(usr_hdr); ul.setContentsMargins(14,0,14,0); ul.setSpacing(8)
        usr_dot = QLabel("●"); usr_dot.setStyleSheet("color:#1E3A4A;font-size:10px;background:transparent;")
        usr_lbl = QLabel("User"); usr_lbl.setStyleSheet("color:#4466AA;font-size:12px;background:transparent;")
        ul.addWidget(usr_dot); ul.addSpacing(4); ul.addWidget(usr_lbl); ul.addStretch()
        vl.addWidget(usr_hdr)

        # Scroll area
        self._scroll = QScrollArea(); self._scroll.setWidgetResizable(True)
        self._scroll.setStyleSheet("background:transparent;border:none;")
        self._scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._scroll.verticalScrollBar().setStyleSheet(
            "QScrollBar:vertical{background:transparent;width:4px;}"
            "QScrollBar::handle:vertical{background:rgba(255,255,255,0.12);border-radius:2px;min-height:20px;}"
            "QScrollBar::add-line:vertical,QScrollBar::sub-line:vertical{height:0;}"
        )
        self._mw = QWidget(); self._mw.setStyleSheet("background:transparent;")
        self._ml = QVBoxLayout(self._mw)
        self._ml.setContentsMargins(10,10,10,10); self._ml.setSpacing(10)
        self._ml.setAlignment(Qt.AlignTop)
        self._scroll.setWidget(self._mw)
        vl.addWidget(self._scroll, 1)

        self._live_u = None; self._live_a = None

    def _user_lbl(self, txt):
        l = QLabel(txt); l.setWordWrap(True); l.setMaximumWidth(250)
        l.setTextInteractionFlags(Qt.TextSelectableByMouse)
        l.setStyleSheet("background:rgba(35,50,80,0.90);border:1px solid rgba(60,100,180,0.35);border-radius:10px;border-bottom-right-radius:3px;padding:8px 12px;color:#CCDDF0;font-size:12px;")
        row = QHBoxLayout(); row.setContentsMargins(0,0,0,0)
        row.addStretch(); row.addWidget(l)
        c = QWidget(); c.setStyleSheet("background:transparent;"); c.setLayout(row)
        self._ml.addWidget(c); QTimer.singleShot(20,self._bot); return l

    def _aria_row(self, txt):
        # AI icon + name header
        hrow = QHBoxLayout(); hrow.setContentsMargins(0,0,0,2); hrow.setSpacing(6)
        ic = QLabel("AI"); ic.setFixedSize(22,22); ic.setAlignment(Qt.AlignCenter)
        ic.setStyleSheet("background:qradialgradient(cx:0.4,cy:0.4,radius:0.8,stop:0 #1166EE,stop:1 #002299);border-radius:11px;color:white;font-size:8px;font-weight:bold;")
        nm = QLabel("AI Assistant"); nm.setStyleSheet("color:#6688AA;font-size:10px;background:transparent;")
        hrow.addWidget(ic); hrow.addWidget(nm); hrow.addStretch()

        l = QLabel(txt); l.setWordWrap(True); l.setMaximumWidth(270)
        l.setTextInteractionFlags(Qt.TextSelectableByMouse)
        l.setStyleSheet("background:transparent;border:none;padding:3px 2px;color:#DDEEFF;font-size:12px;line-height:160%;")

        cw = QWidget(); cw.setStyleSheet("background:transparent;")
        cv = QVBoxLayout(cw); cv.setContentsMargins(0,0,0,0); cv.setSpacing(2)
        cv.addLayout(hrow); cv.addWidget(l)
        self._ml.addWidget(cw); QTimer.singleShot(20,self._bot); return l

    def _sys_lbl(self, txt):
        l = QLabel(txt); l.setAlignment(Qt.AlignCenter)
        l.setStyleSheet("color:rgba(255,255,255,0.20);font-size:10px;background:transparent;padding:2px;")
        self._ml.addWidget(l); QTimer.singleShot(20,self._bot)

    def update_live_user(self, t):
        if not t.strip(): self._live_u = None; return
        if not self._live_u: self._live_u = self._user_lbl(t)
        else: self._live_u.setText(t); QTimer.singleShot(10,self._bot)

    def update_live_aria(self, t):
        if not t.strip(): self._live_a = None; return
        if not self._live_a: self._live_a = self._aria_row(t)
        else: self._live_a.setText(t); QTimer.singleShot(10,self._bot)

    def finalize_user(self, t):
        if self._live_u: self._live_u.setText(t); self._live_u = None
        else: self._user_lbl(t)

    def finalize_aria(self, t):
        if self._live_a: self._live_a.setText(t); self._live_a = None
        else: self._aria_row(t)

    def add_sys(self, t): self._sys_lbl(t)

    def _bot(self):
        sb = self._scroll.verticalScrollBar(); sb.setValue(sb.maximum())


# ══════════════════════════════════════════════════════════════════
# BOTTOM CONTROLS — Exact image Mute + Speak + Camera On/Off
# ══════════════════════════════════════════════════════════════════
class BottomControls(QWidget):
    sig_mute   = pyqtSignal()
    sig_speak  = pyqtSignal()
    sig_camera = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.setFixedHeight(88)
        self.setStyleSheet("background:transparent;")
        vl = QVBoxLayout(self); vl.setContentsMargins(0,8,0,6); vl.setSpacing(7)

        # Row 1: ← ——— [Mute] [Speak] ——— ->
        r1 = QHBoxLayout(); r1.setAlignment(Qt.AlignCenter); r1.setSpacing(0)
        arrow_l = QLabel("——->"); arrow_l.setStyleSheet("color:rgba(255,255,255,0.18);font-size:13px;background:transparent;letter-spacing:-1px;")
        self.mute_btn  = self._btn("🎤  Mute",  "#9A0E1E","#CC1128","#EE2233",136,46)
        self.speak_btn = self._btn("🎤  Speak", "#0E2299","#1133AA","#2255CC",136,46)
        arrow_r = QLabel("←——"); arrow_r.setStyleSheet("color:rgba(255,255,255,0.18);font-size:13px;background:transparent;letter-spacing:-1px;")
        r1.addWidget(arrow_l); r1.addSpacing(10)
        r1.addWidget(self.mute_btn); r1.addSpacing(18); r1.addWidget(self.speak_btn)
        r1.addSpacing(10); r1.addWidget(arrow_r)
        vl.addLayout(r1)

        # Row 2: Camera On/Off
        r2 = QHBoxLayout(); r2.setAlignment(Qt.AlignCenter)
        self.cam_btn = self._btn("🎥  Camera On/Off","#131320","#1C1C35","#252545",168,36)
        r2.addWidget(self.cam_btn)
        vl.addLayout(r2)

        self.mute_btn.clicked.connect(self.sig_mute)
        self.speak_btn.clicked.connect(self.sig_speak)
        self.cam_btn.clicked.connect(self.sig_camera)

    @staticmethod
    def _btn(text, s1, s2, s3, w, h):
        b = QPushButton(text); b.setFixedSize(w,h); b.setCursor(Qt.PointingHandCursor)
        r = h//2
        b.setStyleSheet(f"""
            QPushButton{{
                background:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 {s1},stop:0.5 {s2},stop:1 {s3});
                border:1px solid rgba(255,255,255,0.18);
                border-radius:{r}px;
                color:#FFFFFF;
                font-size:{'13' if h>40 else '11'}px;
                font-weight:bold;
                letter-spacing:0.5px;
            }}
            QPushButton:hover{{
                background:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 {s3},stop:0.5 {s2},stop:1 {s1});
                border:1px solid rgba(255,255,255,0.35);
            }}
            QPushButton:pressed{{background:{s1};border:1px solid rgba(255,255,255,0.10);}}
        """)
        return b


# ══════════════════════════════════════════════════════════════════
# TOP STATUS BAR
# ══════════════════════════════════════════════════════════════════
class TopBar(QWidget):
    sig_mode       = pyqtSignal()
    sig_mic_select = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.setFixedHeight(40)
        self.setStyleSheet("background:rgba(4,8,18,0.98);border-bottom:1px solid rgba(0,70,140,0.22);")
        hl = QHBoxLayout(self); hl.setContentsMargins(18,0,18,0); hl.setSpacing(10)

        self._status = QLabel("● STANDBY")
        self._status.setStyleSheet("color:#2A6644;font-family:'Courier New';font-size:11px;font-weight:bold;background:transparent;letter-spacing:1.5px;")

        self._mode_btn = QPushButton("🌸 ARIA MODE")
        self._mode_btn.setFixedSize(128,26); self._mode_btn.setCursor(Qt.PointingHandCursor)
        self._mode_btn.setStyleSheet("""
            QPushButton{background:rgba(160,40,70,0.16);border:1px solid rgba(200,60,90,0.40);
            border-radius:13px;color:#FF7799;font-size:9px;font-weight:bold;letter-spacing:1px;}
            QPushButton:hover{background:rgba(160,40,70,0.28);}
        """)
        self._mode_btn.clicked.connect(self.sig_mode)

        # Mic selector button
        self._mic_sel_btn = QPushButton("🎙 MIC")
        self._mic_sel_btn.setFixedSize(72,26); self._mic_sel_btn.setCursor(Qt.PointingHandCursor)
        self._mic_sel_btn.setStyleSheet("""
            QPushButton{background:rgba(0,120,80,0.15);border:1px solid rgba(0,180,100,0.35);
            border-radius:13px;color:#44FF88;font-size:9px;font-weight:bold;letter-spacing:1px;}
            QPushButton:hover{background:rgba(0,120,80,0.28);}
        """)
        self._mic_sel_btn.clicked.connect(self.sig_mic_select)

        hl.addWidget(self._status); hl.addStretch()
        hl.addWidget(self._mic_sel_btn)
        hl.addWidget(self._mode_btn)

    def set_status(self, state, label):
        c = {"standby":"#2A6644","listening":"#0077CC","thinking":"#8833BB","speaking":"#BB7700"}.get(state,"#2A6644")
        d = {"standby":"●","listening":"◉","thinking":"◎","speaking":"◉"}.get(state,"●")
        self._status.setText(f"{d} {label}")
        self._status.setStyleSheet(f"color:{c};font-family:'Courier New';font-size:11px;font-weight:bold;background:transparent;letter-spacing:1.5px;")


# ══════════════════════════════════════════════════════════════════
# GEMINI WORKER — Fixed, no extra_headers
# ══════════════════════════════════════════════════════════════════
# ══════════════════════════════════════════════════════════════════
# GEMINI WORKER v8 — ULTRA STABLE (Hours-long sessions)
#
# ROOT CAUSE of 3-min disconnect:
#   Gemini BidiGenerateContent has a hard ~180s session limit.
#   After that it closes the connection silently.
#
# FIXES APPLIED:
#   1. SESSION_RENEW_AFTER=150s — proactive renewal before hard cutoff
#   2. KEEPALIVE every 8s       — server never treats us as idle
#   3. Keepalive send failure    — detects dead connections instantly
#   4. Persistent mic thread    — microphone never stops across reconnects
#   5. Instant reconnect        — seamless, user notices nothing
#   6. Always-on watchdog       — no dependency on user speech
# ══════════════════════════════════════════════════════════════════
class GeminiWorker(QObject):
    sig_status      = pyqtSignal(str, str)
    sig_user_live   = pyqtSignal(str)
    sig_aria_live   = pyqtSignal(str)
    sig_user_msg    = pyqtSignal(str)
    sig_aria_msg    = pyqtSignal(str)
    sig_sys_msg     = pyqtSignal(str)
    sig_tool_call   = pyqtSignal(str)
    sig_tool_result = pyqtSignal(str)
    sig_connected   = pyqtSignal(bool)
    sig_energy      = pyqtSignal(float)

    SESSION_RENEW_AFTER = 150   # Renew before Gemini hard ~180s limit
    KEEPALIVE_INTERVAL  =   8   # Heartbeat every 8s
    # NOTE: NO recv() timeout — Gemini does NOT reply to keepalive pings.
    # recv() should block indefinitely; WS close event handles disconnects.
    # Dead connection is detected by keepalive send failure, not recv timeout.
    MAX_RECONNECT_WAIT  =   1   # Max 1s between reconnects (was 3s)
    RECONNECT_BASE      = 0.1   # 0.1s first retry (was 0.3s)

    def __init__(self):
        super().__init__()
        self.mic_on          = True
        self.running         = True
        self._retry          = 0
        self._ws             = None
        self._loop           = None
        self._prompt         = ARIA_PROMPT
        self._mic_q          = None   # Shared mic queue — survives reconnects

    def set_mic(self, on):
        self.mic_on = on

    def stop(self):
        self.running = False

    def set_prompt(self, p):
        self._prompt = p

    def reconnect(self):
        if self._ws and self._loop:
            asyncio.run_coroutine_threadsafe(self._force_close(), self._loop)

    async def _force_close(self):
        try:
            await self._ws.close()
        except Exception:
            pass

    def send_text(self, text):
        if self._ws and self._loop:
            msg = {"clientContent": {
                "turns": [{"role": "user", "parts": [{"text": text}]}],
                "turnComplete": True
            }}
            asyncio.run_coroutine_threadsafe(self._safe_send(_enc(msg)), self._loop)

    async def _safe_send(self, data):
        try:
            await self._ws.send(data)
        except Exception as e:
            print(f"[ARIA] send: {e}")

    def start_thread(self):
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        self._loop = loop
        try:
            loop.run_until_complete(self._main())
        finally:
            loop.close()

    async def _main(self):
        """
        Main outer loop.
        - Starts ONE persistent mic thread (never restarts)
        - Reconnects WebSocket as many times as needed
        - Clears stale audio between sessions
        """
        import queue as Q
        self._mic_q = Q.Queue(maxsize=300)

        # Start mic thread — runs forever independent of WS
        mic_t = threading.Thread(target=self._mic_thread, daemon=True)
        mic_t.start()

        first = True
        while self.running:
            try:
                await self._session(first)
                first    = False
                self._retry = 0
            except Exception as e:
                print(f"[ARIA] Session error: {type(e).__name__}: {e}")
                self.sig_connected.emit(False)
                wait = min(self.RECONNECT_BASE * (2 ** min(self._retry, 4)),
                           self.MAX_RECONNECT_WAIT)
                self._retry += 1
                self.sig_status.emit("standby", f"RECONNECTING...")
                await asyncio.sleep(wait)

            # Drain mic queue before new session (avoid sending old audio)
            drained = 0
            while not self._mic_q.empty():
                try:
                    self._mic_q.get_nowait()
                    drained += 1
                except Exception:
                    break
            if drained:
                print(f"[ARIA] Drained {drained} stale mic frames")

    def _mic_thread(self):
        """
        PERSISTENT mic capture — survives all reconnects.
        Uses _MIC_DEVICE if set, else auto-selects best mic.
        Puts (pcm_bytes, rms) into self._mic_q.
        """
        # Auto-detect best mic on first run
        mic_device = _MIC_DEVICE
        if mic_device is None:
            mic_device = _get_best_mic_device()

        while self.running:
            try:
                with sd.InputStream(
                    device     = mic_device,
                    samplerate = MIC_RATE,
                    channels   = 1,
                    dtype      = "int16",
                    blocksize  = FRAMES,
                    latency    = "low",
                ) as mic:
                    print(f"[MIC] Stream started - device: {mic_device}")
                    while self.running:
                        pcm, overflowed = mic.read(FRAMES)
                        if overflowed:
                            pass  # Minor overflow ok
                        if not self.mic_on:
                            time.sleep(0.02)
                            continue
                        rms = float(np.sqrt(np.mean(pcm.astype(np.float32) ** 2)))
                        try:
                            self.sig_energy.emit(rms)
                        except Exception:
                            pass
                        try:
                            self._mic_q.put_nowait((pcm.tobytes(), rms))
                        except Exception:
                            pass  # Queue full — drop oldest is fine
            except Exception as e:
                print(f"[MIC] Error (device={mic_device}): {e}")
                # If selected device fails, fall back to system default
                if mic_device is not None:
                    print("[MIC] Falling back to system default mic")
                    mic_device = None
                time.sleep(0.5)

    async def _session(self, first: bool = False):
        """
        One WebSocket session.
        Exits cleanly after SESSION_RENEW_AFTER seconds -> _main reconnects.
        """
        session_start = time.monotonic()

        async with websockets.connect(
            f"{_WS_URL}?key={_API_KEY}",
            max_size      = None,
            ping_interval = None,   # Gemini rejects WS ping (1008)
            ping_timeout  = None,
            close_timeout = 6,
            compression   = None,
        ) as ws:
            self._ws = ws
            self.sig_connected.emit(True)
            self._retry = 0

            # Setup
            await ws.send(_enc(_make_setup(self._prompt)))
            try:
                await asyncio.wait_for(ws.recv(), timeout=15)  # setup ack only
            except asyncio.TimeoutError:
                raise ConnectionError("Setup ack timeout")

            self.sig_status.emit("standby", "STANDBY")
            if first:
                self.sig_sys_msg.emit("⚡  ARIA ONLINE")
            else:
                # Silent reconnect — user doesn't see spam
                print(f"[ARIA] Reconnected (session #{self._retry})")

            import queue as Q
            _aq   = Q.Queue(maxsize=400)
            _stop = threading.Event()

            # ── Audio playback thread ─────────────────────────────
            def _play():
                BUF = int(SPK_RATE * AUDIO_BUF_MS / 1000)
                buf = np.array([], dtype=np.float32)
                st  = sd.OutputStream(
                    device     = _SPK_DEVICE,
                    samplerate = SPK_RATE,
                    channels   = 1,
                    dtype      = "float32",
                    blocksize  = BUF,
                    latency    = "low",
                )
                st.start()
                while not _stop.is_set():
                    try:
                        chunk = _aq.get(timeout=0.08)
                        if chunk is None:
                            if len(buf):
                                pad = BUF - (len(buf) % BUF or BUF)
                                if pad:
                                    buf = np.concatenate([buf, np.zeros(pad, np.float32)])
                                st.write(buf)
                                buf = np.array([], dtype=np.float32)
                            continue
                        buf = np.concatenate([buf, chunk])
                        while len(buf) >= BUF:
                            st.write(buf[:BUF])
                            buf = buf[BUF:]
                    except Q.Empty:
                        if len(buf) >= BUF:
                            st.write(buf[:BUF])
                            buf = buf[BUF:]
                st.stop()
                st.close()

            pt = threading.Thread(target=_play, daemon=True)
            pt.start()

            # ── Send coroutine — reads from persistent _mic_q ────────
            async def send():
                was_live = False
                silent   = 0
                ended    = False

                while self.running:
                    # Proactive session renewal
                    if time.monotonic() - session_start >= self.SESSION_RENEW_AFTER:
                        print(f"[ARIA] send: session age limit -> renewal")
                        return

                    # Read mic data
                    try:
                        pcm_bytes, rms = self._mic_q.get_nowait()
                    except Exception:
                        await asyncio.sleep(0.005)
                        continue

                    if not self.mic_on:
                        was_live = False; silent = 0; ended = False
                        continue

                    is_speech = rms >= SILENCE_RMS

                    if is_speech:
                        silent = 0; ended = False
                        if not was_live:
                            was_live = True
                            self.sig_status.emit("listening", "LISTENING")
                        try:
                            await ws.send(_enc({
                                "realtimeInput": {
                                    "audio": {
                                        "mimeType": "audio/pcm;rate=16000",
                                        "data": base64.b64encode(pcm_bytes).decode()
                                    }
                                }
                            }))
                        except Exception:
                            return
                    else:
                        silent += 1
                        if was_live and silent == SILENCE_FRAMES and not ended:
                            was_live = False; ended = True
                            self.sig_status.emit("thinking", "THINKING")
                            try:
                                await ws.send(_enc({"realtimeInput": {"audioStreamEnd": True}}))
                            except Exception:
                                return

            # ── Recv coroutine ────────────────────────────────────────
            async def recv():
                aria_buf = ""; user_buf = ""; speaking = False

                while self.running:
                    if time.monotonic() - session_start >= self.SESSION_RENEW_AFTER:
                        print(f"[ARIA] recv: session age limit -> renewal")
                        return

                    try:
                        # NO timeout here — Gemini does NOT ack keepalive pings.
                        # Adding a timeout causes false "disconnect" after every quiet period.
                        # Connection death is detected by keepalive send() failure instead.
                        raw = await ws.recv()
                        msg = json.loads(raw)
                    except websockets.exceptions.ConnectionClosed as e:
                        print(f"[ARIA] Connection closed: {e}")
                        return
                    except Exception as e:
                        print(f"[recv] {e}")
                        continue

                    # Tool calls
                    for call in msg.get("toolCall", {}).get("functionCalls", []):
                        n = call["name"]; a = call.get("args", {})
                        self.sig_tool_call.emit(f"⚙  {n}")
                        self.sig_status.emit("thinking", "TOOL: " + n[:14])
                        try:
                            res = await dispatch(n, a)
                            if _HAS_ADV:
                                ARIAMemory.add_note(f"T:{n}", str(res)[:200], ["tool"])
                        except Exception as e:
                            res = f"❌ {e}"
                        self.sig_tool_result.emit(f"✓ {n}: {str(res)[:100]}")
                        try:
                            await ws.send(_enc({
                                "toolResponse": {
                                    "functionResponses": [{
                                        "id": call["id"], "name": n,
                                        "response": {"result": str(res)}
                                    }]
                                }
                            }))
                        except Exception:
                            return

                    sc = msg.get("serverContent", {})
                    if not sc:
                        continue

                    if sc.get("interrupted"):
                        self.sig_status.emit("listening", "LISTENING")
                        aria_buf = ""; speaking = False
                        while not _aq.empty():
                            try: _aq.get_nowait()
                            except Exception: break

                    for part in sc.get("modelTurn", {}).get("parts", []):
                        d = part.get("inlineData")
                        if d and d.get("mimeType", "").startswith("audio/pcm"):
                            if not speaking:
                                speaking = True
                                self.sig_status.emit("speaking", "SPEAKING")
                            raw_b = base64.b64decode(d["data"])
                            chunk = np.frombuffer(raw_b, dtype=np.int16).astype(np.float32) / 32768.0
                            try:
                                _aq.put_nowait(chunk)
                            except Exception:
                                pass

                    ot = sc.get("outputTranscript", "")
                    if ot:
                        aria_buf += ot
                        self.sig_aria_live.emit(aria_buf)

                    it = sc.get("inputTranscript", "")
                    if it:
                        user_buf += it
                        self.sig_user_live.emit(user_buf)

                    if sc.get("turnComplete") or sc.get("generationComplete"):
                        _aq.put(None)
                        if aria_buf.strip():
                            self.sig_aria_msg.emit(aria_buf.strip())
                            asyncio.create_task(memory_save("aria", aria_buf.strip()))
                            if _HAS_ADV:
                                ARIAMemory.add_conversation("aria", aria_buf.strip())
                        aria_buf = ""
                        if user_buf.strip():
                            self.sig_user_msg.emit(user_buf.strip())
                            asyncio.create_task(memory_save("user", user_buf.strip()))
                            if _HAS_ADV:
                                ARIAMemory.add_conversation("user", user_buf.strip())
                        user_buf = ""; speaking = False
                        self.sig_status.emit("standby", "STANDBY")
                        self.sig_aria_live.emit("")
                        self.sig_user_live.emit("")

            # ── Keepalive coroutine ───────────────────────────────────
            # Strategy:
            # - Send heartbeat every 8s so Gemini knows we're alive
            # - Gemini does NOT reply to keepalives — this is expected
            # - Proactively renew session at 150s before hard ~180s cutoff
            # - If keepalive send FAILS -> connection is dead -> return -> reconnect
            async def keepalive():
                last_kp = time.monotonic()

                while self.running:
                    await asyncio.sleep(2)
                    now = time.monotonic()
                    age = now - session_start

                    # Proactive session renewal — before Gemini's hard limit
                    if age >= self.SESSION_RENEW_AFTER:
                        print(f"[ARIA] Renewal: age={age:.0f}s")
                        try:
                            await ws.close()
                        except Exception:
                            pass
                        return

                    # Send keepalive heartbeat
                    if now - last_kp >= self.KEEPALIVE_INTERVAL:
                        try:
                            await ws.send(_enc({
                                "clientContent": {
                                    "turns": [],
                                    "turnComplete": False
                                }
                            }))
                            last_kp = now
                            remaining = self.SESSION_RENEW_AFTER - age
                            print(f"[ARIA] <3 age={age:.0f}s rem={remaining:.0f}s")
                        except websockets.exceptions.ConnectionClosed:
                            print("[ARIA] keepalive: connection dead -> reconnect")
                            return
                        except Exception as e:
                            print(f"[ARIA] keepalive err: {e} -> reconnect")
                            return

            # ── Run all three coroutines ──────────────────────────────
            try:
                tasks = [
                    asyncio.ensure_future(send()),
                    asyncio.ensure_future(recv()),
                    asyncio.ensure_future(keepalive()),
                ]
                done, pending = await asyncio.wait(
                    tasks, return_when=asyncio.FIRST_COMPLETED
                )
                for t in pending:
                    t.cancel()
                    try:
                        await t
                    except (asyncio.CancelledError, Exception):
                        pass
            finally:
                _stop.set()
                _aq.put(None)
                pt.join(timeout=2.0)
                self._ws = None
                age = time.monotonic() - session_start
                print(f"[ARIA] Session ended after {age:.1f}s")


# ══════════════════════════════════════════════════════════════════
# MIC SELECTION DIALOG
# ══════════════════════════════════════════════════════════════════
class MicSelectDialog(QDialog):
    sig_devices_set = pyqtSignal(int, int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Select Audio Devices")
        self.setFixedWidth(400)
        self.setStyleSheet("""
            QDialog { background: #040810; color: #CCDDEE; border: 1px solid rgba(0,80,160,0.3); }
            QLabel { color: #88AABB; font-weight: bold; margin-top: 10px; }
            QComboBox { 
                background: #061224; border: 1px solid rgba(0,100,200,0.3); 
                color: #FFFFFF; padding: 5px; border-radius: 5px; min-height: 24px;
            }
            QPushButton { 
                background: #0A2440; border: 1px solid #1A4470; color: #CCDDEE; 
                padding: 6px 15px; border-radius: 4px; min-width: 80px; 
            }
            QPushButton:hover { background: #12365C; border-color: #2466AA; }
        """)
        
        vl = QVBoxLayout(self)
        vl.setContentsMargins(20, 20, 20, 20)
        vl.setSpacing(10)
        
        # Mic selection
        vl.addWidget(QLabel("🎤 Microphone Input:"))
        self.mic_combo = QComboBox()
        vl.addWidget(self.mic_combo)
        
        # Speaker selection
        vl.addWidget(QLabel("🔊 Speaker Output:"))
        self.spk_combo = QComboBox()
        vl.addWidget(self.spk_combo)
        
        self._populate_devices()
        
        vl.addSpacing(15)
        
        # Buttons
        btns = QHBoxLayout()
        ok_btn = QPushButton("Confirm")
        can_btn = QPushButton("Cancel")
        ok_btn.clicked.connect(self.accept)
        can_btn.clicked.connect(self.reject)
        btns.addStretch()
        btns.addWidget(can_btn)
        btns.addWidget(ok_btn)
        vl.addLayout(btns)

    def _populate_devices(self):
        import sounddevice as sd
        devices = sd.query_devices()
        
        # Fallback to defaults if global is None
        def_mic = sd.default.device[0]
        def_spk = sd.default.device[1]
        
        curr_mic = _MIC_DEVICE if _MIC_DEVICE is not None else def_mic
        curr_spk = _SPK_DEVICE if _SPK_DEVICE is not None else def_spk

        for i, d in enumerate(devices):
            if d["max_input_channels"] > 0:
                self.mic_combo.addItem(f"[{i}] {d['name']}", i)
                if i == curr_mic:
                    self.mic_combo.setCurrentIndex(self.mic_combo.count() - 1)
            
            if d["max_output_channels"] > 0:
                self.spk_combo.addItem(f"[{i}] {d['name']}", i)
                if i == curr_spk:
                    self.spk_combo.setCurrentIndex(self.spk_combo.count() - 1)

    def accept(self):
        mic_idx = self.mic_combo.currentData()
        spk_idx = self.spk_combo.currentData()
        self.sig_devices_set.emit(mic_idx, spk_idx)
        super().accept()


class ARIAWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ARIA — AI Voice Assistant")
        self.setMinimumSize(1120,660); self.resize(1300,750)
        self._mode   = "aria"
        self._mic_on = True
        self._build_ui()
        self._start_worker()

    def _build_ui(self):
        self.setStyleSheet("QMainWindow,QWidget{background:#040810;color:#CCDDEEFF;}")
        root = QWidget(); root.setStyleSheet("background:#040810;"); self.setCentralWidget(root)
        root_vl = QVBoxLayout(root); root_vl.setContentsMargins(0,0,0,0); root_vl.setSpacing(0)

        # Top status bar
        self._topbar = TopBar()
        self._topbar.sig_mode.connect(self._on_mode)
        self._topbar.sig_mic_select.connect(self._on_mic_select)
        root_vl.addWidget(self._topbar)

        # Main body
        body = QWidget(); body.setStyleSheet("background:#040810;")
        hl = QHBoxLayout(body); hl.setContentsMargins(0,0,0,0); hl.setSpacing(0)

        # LEFT
        self._sidebar = LeftSidebar()
        hl.addWidget(self._sidebar)

        # CENTER
        center = QWidget(); center.setStyleSheet("background:#040810;")
        cvl = QVBoxLayout(center); cvl.setContentsMargins(0,0,0,0); cvl.setSpacing(0)
        self._orb = GoalOrb()
        cvl.addWidget(self._orb, 1)
        self._ctrl = BottomControls()
        self._ctrl.sig_mute.connect(self._on_mute)
        self._ctrl.sig_speak.connect(self._on_speak)
        self._ctrl.sig_camera.connect(self._on_camera)
        cvl.addWidget(self._ctrl)
        hl.addWidget(center, 1)

        # RIGHT
        right = QWidget(); right.setFixedWidth(322)
        right.setStyleSheet("background:#050D1E;border-left:1px solid rgba(0,60,130,0.22);")
        rvl = QVBoxLayout(right); rvl.setContentsMargins(10,10,10,10); rvl.setSpacing(10)
        self._stats = StatsWidget(); rvl.addWidget(self._stats)
        self._chat  = ChatWidget();  rvl.addWidget(self._chat, 1)
        hl.addWidget(right)

        root_vl.addWidget(body, 1)

    # ── Signal handlers ──────────────────────────────────────
    def _on_status(self, state, label):
        self._topbar.set_status(state, label)
        m = {"standby":"idle","listening":"listening","thinking":"thinking","speaking":"speaking"}
        self._orb.set_state(m.get(state,"idle"))

    def _on_energy(self, e):
        if self._mic_on: self._orb.set_energy(e)

    def _on_user_live(self, t): self._chat.update_live_user(t)
    def _on_aria_live(self, t): self._chat.update_live_aria(t)
    def _on_user_msg(self, t):  self._chat.finalize_user(t)
    def _on_aria_msg(self, t):  self._chat.finalize_aria(t)
    def _on_sys_msg(self, t):   self._chat.add_sys(t)
    def _on_tool_call(self,t):  self._chat.add_sys(t)
    def _on_tool_result(self,t):self._chat.add_sys(t)

    def _on_connected(self, ok):
        if ok:
            self._chat.add_sys("⚡ ARIA Online")
            QTimer.singleShot(1500, self._greet)
        else:
            self._chat.add_sys("⚠ Reconnecting...")

    def _greet(self):
        g = ("Greet me with Assalamu Alaikum in Bangla. Say your name is ARIA. Ask how I am. Friendly, short, casual Bangla with Islamic warmth."
             if self._mode=="aria"
             else "Greet me with Assalamu Alaikum in Bangla as ARIA. Ask how you can help. Brief, professional Bangla.")
        self._worker.send_text(g)

    def _on_mic_select(self):
        dlg = MicSelectDialog(self)
        dlg.sig_devices_set.connect(self._apply_devices)
        dlg.show()

    def _apply_devices(self, mic_idx, spk_idx):
        """Apply new mic/speaker selection and restart worker to take effect."""
        global _MIC_DEVICE, _SPK_DEVICE
        _MIC_DEVICE = mic_idx
        _SPK_DEVICE = spk_idx
        self._chat.add_sys(f"🎙 Mic changed -> reconnecting...")
        # Stop current worker; give it 1.2s to wind down before restarting
        self._worker.stop()
        QTimer.singleShot(1200, self._restart_worker)

    def _restart_worker(self):
        self._start_worker()
        self._chat.add_sys("✅ New mic/speaker active!")

    _MUTE_STYLE_NORMAL = """
        QPushButton{
            background:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #9A0E1E,stop:0.5 #CC1128,stop:1 #EE2233);
            border:1px solid rgba(255,255,255,0.18);border-radius:23px;
            color:#FFFFFF;font-size:13px;font-weight:bold;letter-spacing:0.5px;}
        QPushButton:hover{
            background:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #EE2233,stop:0.5 #CC1128,stop:1 #9A0E1E);
            border:1px solid rgba(255,255,255,0.35);}
        QPushButton:pressed{background:#9A0E1E;border:1px solid rgba(255,255,255,0.10);}
    """
    _MUTE_STYLE_MUTED = """
        QPushButton{
            background:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #660A14,stop:0.5 #881020,stop:1 #AA1828);
            border:1px solid rgba(255,255,255,0.12);border-radius:23px;
            color:#FF9999;font-size:13px;font-weight:bold;letter-spacing:0.5px;}
        QPushButton:hover{
            background:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #AA1828,stop:0.5 #881020,stop:1 #660A14);
            border:1px solid rgba(255,255,255,0.25);}
        QPushButton:pressed{background:#660A14;border:1px solid rgba(255,255,255,0.10);}
    """

    def _on_mute(self):
        self._mic_on = False; self._worker.set_mic(False)
        self._orb.set_state("idle")
        self._topbar.set_status("standby","MUTED 🔇")
        self._ctrl.mute_btn.setStyleSheet(self._MUTE_STYLE_MUTED)

    def _on_speak(self):
        self._mic_on = True; self._worker.set_mic(True)
        self._topbar.set_status("listening","LISTENING")
        # Restore original mute button style
        self._ctrl.mute_btn.setStyleSheet(self._MUTE_STYLE_NORMAL)

    def _on_camera(self):
        self._sidebar.toggle_camera()
        is_on = self._sidebar._cam_on
        label = "🎥  Camera Off" if is_on else "🎥  Camera On/Off"
        self._ctrl.cam_btn.setText(label)

    def _on_mode(self):
        self._mode = "normal" if self._mode=="aria" else "aria"
        p = ARIA_PROMPT if self._mode=="aria" else NORMAL_PROMPT
        lbl = "🌸 ARIA MODE" if self._mode=="aria" else "👔 NORMAL MODE"
        self._topbar._mode_btn.setText(lbl)
        sty = ("""QPushButton{background:rgba(160,40,70,0.16);border:1px solid rgba(200,60,90,0.40);
                border-radius:13px;color:#FF7799;font-size:9px;font-weight:bold;letter-spacing:1px;}
                QPushButton:hover{background:rgba(160,40,70,0.28);}"""
               if self._mode=="aria" else
               """QPushButton{background:rgba(20,60,160,0.16);border:1px solid rgba(50,110,220,0.40);
                border-radius:13px;color:#7799FF;font-size:9px;font-weight:bold;letter-spacing:1px;}
                QPushButton:hover{background:rgba(20,60,160,0.28);}""")
        self._topbar._mode_btn.setStyleSheet(sty)
        self._worker.set_prompt(p); self._worker.reconnect()
        self._chat.add_sys(f"🔄 Mode: {'ARIA 🌸' if self._mode=='aria' else 'Normal 👔'}")

    def _start_worker(self):
        init_advanced_features(api_key=_API_KEY)
        try: init_advanced(api_key=_API_KEY, suggestion_cb=lambda s:None)
        except: pass
        self._worker = GeminiWorker()
        self._worker.sig_status.connect(self._on_status)
        self._worker.sig_user_live.connect(self._on_user_live)
        self._worker.sig_aria_live.connect(self._on_aria_live)
        self._worker.sig_user_msg.connect(self._on_user_msg)
        self._worker.sig_aria_msg.connect(self._on_aria_msg)
        self._worker.sig_sys_msg.connect(self._on_sys_msg)
        self._worker.sig_tool_call.connect(self._on_tool_call)
        self._worker.sig_tool_result.connect(self._on_tool_result)
        self._worker.sig_connected.connect(self._on_connected)
        self._worker.sig_energy.connect(self._on_energy)
        self._worker.start_thread()

    def closeEvent(self, e):
        self._worker.stop()
        if self._sidebar._cam_on: self._sidebar._cam_thread.stop_camera()
        if _HAS_ADV: ARIAMemory.save()
        super().closeEvent(e)


if __name__ == "__main__":
    # python aria.py --list-devices   ->  shows all mics & speakers then exits
    if "--list-devices" in sys.argv:
        list_audio_devices()
        sys.exit(0)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    pal = QPalette()
    pal.setColor(QPalette.Window,          QColor("#040810"))
    pal.setColor(QPalette.WindowText,      QColor("#CCDDEEFF"))
    pal.setColor(QPalette.Base,            QColor("#070E1C"))
    pal.setColor(QPalette.Text,            QColor("#CCDDEEFF"))
    pal.setColor(QPalette.Button,          QColor("#0A1428"))
    pal.setColor(QPalette.ButtonText,      QColor("#CCDDEEFF"))
    pal.setColor(QPalette.Highlight,       QColor("#1144AA"))
    pal.setColor(QPalette.HighlightedText, QColor("#FFFFFF"))
    app.setPalette(pal)
    win = ARIAWindow(); win.show()
    sys.exit(app.exec_())