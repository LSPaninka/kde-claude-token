"""
Offscreen render harness for the Plasma 6 plasmoids.

Stubs the KDE QML modules (plasmoid, core, plasma5support, components, kirigami)
just enough to instantiate the REAL main.qml, its compact and full
representations, and ColorButton; feeds canned API responses through the
Plasma5Support.DataSource stub; and saves screenshots plus every QML warning.

usage: run.py <package_dir> <scenario> <out_png> [key=value config overrides...]
"""
import json, os, sys, time, re, xml.etree.ElementTree as ET
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, Slot, Property, QUrl, QTimer, qInstallMessageHandler, QtMsgType
from PySide6.QtGui import QGuiApplication, QImage, QPainter, QColor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow  # noqa: F401  (registers wrapper so grabWindow exists)

pkg = Path(sys.argv[1]).resolve()
scenario = sys.argv[2]
out_png = Path(sys.argv[3]).resolve()
overrides = dict(a.split("=", 1) for a in sys.argv[4:] if "=" in a)
form_factor = int(overrides.pop("formFactor", "2"))   # 2 = Horizontal panel

HERE = Path(__file__).parent
STUBS = HERE / "stubs_run"
FIX = HERE / "fixtures"

# ---------------------------------------------------------------- messages
messages = []
def handler(mode, ctx, msg):
    kind = {QtMsgType.QtDebugMsg: "debug", QtMsgType.QtInfoMsg: "info",
            QtMsgType.QtWarningMsg: "WARNING", QtMsgType.QtCriticalMsg: "CRITICAL",
            QtMsgType.QtFatalMsg: "FATAL"}.get(mode, str(mode))
    messages.append(f"{kind}: {msg}")
qInstallMessageHandler(handler)

# ---------------------------------------------------------------- stubs
def write(p, text):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

def config_props():
    """Typed QML properties from the package's own main.xml defaults (+ overrides)."""
    ns = {"k": "http://www.kde.org/standards/kcfg/1.0"}
    root = ET.parse(pkg / "contents/config/main.xml").getroot()
    out = []
    for e in root.iter("{http://www.kde.org/standards/kcfg/1.0}entry"):
        name, typ = e.get("name"), e.get("type")
        d = e.find("k:default", ns)
        val = overrides.get(name, (d.text or "") if d is not None else "")
        if typ == "Int":
            out.append(f"property int {name}: {int(val)}")
        elif typ == "Bool":
            out.append(f"property bool {name}: {'true' if str(val).lower() == 'true' else 'false'}")
        else:
            out.append(f"property string {name}: {json.dumps(val)}")
    return "\n        ".join(out)

def build_stubs():
    import shutil
    shutil.rmtree(STUBS, ignore_errors=True)
    b = STUBS / "org/kde"
    # --- org.kde.plasma.plasmoid
    write(b / "plasma/plasmoid/qmldir",
          "module org.kde.plasma.plasmoid\nPlasmoidItem 1.0 PlasmoidItem.qml\nsingleton Plasmoid 1.0 Plasmoid.qml\n")
    write(b / "plasma/plasmoid/PlasmoidItem.qml", """import QtQuick
Item {
    property Component compactRepresentation
    property Component fullRepresentation
    property var preferredRepresentation
    property bool expanded: false
    property string toolTipMainText
    property string toolTipSubText
}
""")
    write(b / "plasma/plasmoid/Plasmoid.qml", f"""pragma Singleton
import QtQuick
QtObject {{
    property int formFactor: {form_factor}
    property QtObject configuration: QtObject {{
        {config_props()}
    }}
}}
""")
    # --- org.kde.plasma.core  (FormFactor enum: Planar, MediaCenter, Horizontal, Vertical)
    write(b / "plasma/core/qmldir", "module org.kde.plasma.core\nTypes 1.0 Types.qml\n")
    write(b / "plasma/core/Types.qml", """import QtQuick
QtObject { enum FormFactor { Planar, MediaCenter, Horizontal, Vertical } }
""")
    # --- org.kde.plasma.plasma5support  (executable engine -> canned fixtures)
    write(b / "plasma/plasma5support/qmldir", "module org.kde.plasma.plasma5support\nDataSource 1.0 DataSource.qml\n")
    write(b / "plasma/plasma5support/DataSource.qml", """import QtQuick
QtObject {
    property string engine
    property var connectedSources: []
    signal newData(string sourceName, var data)
    function connectSource(s) {
        harnessLog.log("connectSource " + (s.indexOf("rate-limit-reset-credits") >= 0 ? "[reset-credits]"
                       : s.indexOf("wham/usage") >= 0 ? "[codex-usage]" : s.indexOf("oauth/usage") >= 0 ? "[claude-usage]" : s));
        connectedSources = connectedSources.concat([s]);
        Qt.callLater(() => newData(s, { "stdout": harnessFixtures.pick(s), "stderr": "", "exit code": 0 }));
    }
    function disconnectSource(s) { connectedSources = connectedSources.filter(x => x !== s); }
}
""")
    # --- org.kde.plasma.components (PC3 wraps QQC2)
    write(b / "plasma/components/qmldir",
          "module org.kde.plasma.components\nLabel 1.0 Label.qml\nToolButton 1.0 ToolButton.qml\nBusyIndicator 1.0 BusyIndicator.qml\n")
    for t in ("Label", "ToolButton", "BusyIndicator"):
        write(b / f"plasma/components/{t}.qml", f"import QtQuick.Controls as T\nT.{t} {{}}\n")
    # --- org.kde.kirigami
    write(b / "kirigami/qmldir",
          "module org.kde.kirigami\nsingleton Theme 1.0 Theme.qml\nsingleton Units 1.0 Units.qml\nIcon 1.0 Icon.qml\n")
    write(b / "kirigami/Theme.qml", """pragma Singleton
import QtQuick
QtObject {
    property color textColor: "#fcfcfc"
    property color negativeTextColor: "#da4453"
    property font smallFont: Qt.font({ pointSize: 8 })
}
""")
    write(b / "kirigami/Units.qml", """pragma Singleton
import QtQuick
QtObject {
    property int gridUnit: 18
    property int smallSpacing: 4
    property int largeSpacing: 8
    property QtObject iconSizes: QtObject {
        property int small: 16; property int smallMedium: 22; property int medium: 32; property int large: 48
    }
}
""")
    # Placeholder icon: a labelled box, so we can see WHICH icon name was requested.
    write(b / "kirigami/Icon.qml", """import QtQuick
Rectangle {
    property var source
    property var fallback
    implicitWidth: 16; implicitHeight: 16
    color: source === "gift" ? "#c0392b" : "#3d6e99"; radius: 3
    Text { anchors.centerIn: parent; text: String(parent.source).substring(0, 1).toUpperCase()
           color: "white"; font.pixelSize: Math.max(7, parent.height * 0.7); font.bold: true }
}
""")

# ---------------------------------------------------------------- python side
class Ctx(QObject):
    """Context object: provides i18n() like KLocalizedContext does in Plasma."""
    @Slot(str, result=str)
    @Slot(str, "QVariant", result=str)
    @Slot(str, "QVariant", "QVariant", result=str)
    def i18n(self, s, a=None, b=None):
        for n, v in ((1, a), (2, b)):
            if v is not None:
                s = s.replace(f"%{n}", str(v))
        return s

class Fixtures(QObject):
    def __init__(self):
        super().__init__()
        self.mode = "ok"
    @Slot(str)
    def setMode(self, m):
        self.mode = m
    @Slot(str, result=str)
    def pick(self, cmd):
        if self.mode == "error":
            return '{"error":{"message":"Invalid bearer token"}}'
        if "rate-limit-reset-credits" in cmd:
            return (FIX / "codex_resets.json").read_text()
        if "wham/usage" in cmd:
            name = "codex_notstarted.json" if self.mode == "notstarted" else "codex_usage.json"
            return (FIX / name).read_text()
        return (FIX / "claude_usage.json").read_text()

class Log(QObject):
    @Slot(str)
    def log(self, m):
        messages.append("harness: " + m)

snaps = []
class Snapper(QObject):
    def __init__(self, engine):
        super().__init__()
        self.engine = engine
    @Slot(str)
    def snap(self, label):
        win = self.engine.rootObjects()[0]
        snaps.append((label, win.grabWindow()))
    @Slot()
    def done(self):
        QTimer.singleShot(0, app.quit)

# ---------------------------------------------------------------- fixtures (times relative to now)
def make_fixtures():
    now = time.time()
    FIX.mkdir(exist_ok=True)
    iso = lambda t: time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime(t))
    claude = {"five_hour": {"utilization": 26.0, "resets_at": iso(now + 2*3600 + 25*60)},
              "seven_day": {"utilization": 62.0, "resets_at": iso(now + 3*86400 + 4*3600)}}
    (FIX / "claude_usage.json").write_text(json.dumps(claude))
    codex = {"plan_type": "plus", "rate_limit": {"allowed": True, "limit_reached": False,
             "primary_window": {"used_percent": 41, "limit_window_seconds": 18000, "reset_after_seconds": 9000, "reset_at": int(now + 9000)},
             "secondary_window": {"used_percent": 12, "limit_window_seconds": 604800, "reset_after_seconds": 400000, "reset_at": int(now + 400000)}}}
    (FIX / "codex_usage.json").write_text(json.dumps(codex))
    ns = {"plan_type": "plus", "rate_limit": {"allowed": True, "limit_reached": False,
          "primary_window": {"used_percent": 0, "limit_window_seconds": 18000, "reset_after_seconds": 18000, "reset_at": int(now + 18000)},
          "secondary_window": {"used_percent": 0, "limit_window_seconds": 604800, "reset_after_seconds": 604800, "reset_at": int(now + 604800)}}}
    (FIX / "codex_notstarted.json").write_text(json.dumps(ns))
    resets = {"credits": [{"title": "Restablecimiento total (semanal + 5 h)", "status": "available",
              "granted_at": "2026-08-21T23:16:43.034034Z", "expires_at": "2026-09-20T23:16:43.034034Z"}],
              "available_count": 1}
    (FIX / "codex_resets.json").write_text(json.dumps(resets))

# ---------------------------------------------------------------- run
build_stubs()
make_fixtures()
app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
engine.addImportPath(str(STUBS))
ctx_obj, fixtures, log, snapper = Ctx(), Fixtures(), Log(), Snapper(engine)
rc = engine.rootContext()
rc.setContextObject(ctx_obj)
rc.setContextProperty("harnessFixtures", fixtures)
rc.setContextProperty("harnessLog", log)
rc.setContextProperty("harness", snapper)
rc.setContextProperty("scenario", scenario)
rc.setContextProperty("pkgUrl", QUrl.fromLocalFile(str(pkg / "contents") + "/"))
engine.load(QUrl.fromLocalFile(str(HERE / "Harness.qml")))
if not engine.rootObjects():
    print("\n".join(messages)); sys.exit("Harness failed to load")
QTimer.singleShot(15000, app.quit)   # safety net
app.exec()

# stitch snapshots vertically with labels
w = max(img.width() for _, img in snaps) if snaps else 10
h = sum(img.height() + 22 for _, img in snaps) if snaps else 10
sheet = QImage(w, h, QImage.Format_ARGB32); sheet.fill(QColor("#111"))
p = QPainter(sheet); y = 0
for label, img in snaps:
    p.setPen(QColor("#ffd54f")); p.drawText(8, y + 16, label); y += 22
    p.drawImage(0, y, img); y += img.height()
p.end()
sheet.save(str(out_png))
print(f"saved {out_png} ({len(snaps)} frames)")
print("\n".join(m for m in messages))
