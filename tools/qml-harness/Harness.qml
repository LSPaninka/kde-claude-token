import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: win
    width: 720; height: scenario === "separator" ? 70 : 320
    visible: true
    color: "#1b1e20"

    property var applet: null
    property var colorButtonResult: ""

    // ---- fake horizontal panel, 44 px thick like the user's ----
    Rectangle {
        id: panelBg
        x: 0; y: 8; width: parent.width; height: 44
        color: "#2a2e32"
        RowLayout {
            id: panel
            x: 8; height: parent.height; spacing: 8
            Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; color: "#c0392b"; radius: 4
                        Text { anchors.centerIn: parent; text: "2"; color: "white"; font.bold: true; font.pixelSize: 20 } }
        }
    }

    // ---- popup area for the full representation ----
    Rectangle {
        id: popupFrame
        visible: scenario !== "separator"
        x: 8; y: 64; width: 18 * 18 + 16; height: 12 * 18 + 30
        color: "#31363b"; radius: 6; border.color: "#4d5359"
        Item { id: popup; anchors.fill: parent; anchors.margins: 6 }
    }
    Text {
        visible: scenario !== "separator"
        x: popupFrame.x + popupFrame.width + 16; y: 70; width: win.width - x - 8
        color: "#bbb"; font.pixelSize: 11; wrapMode: Text.Wrap
        text: "scenario: " + scenario
              + "\nColorButton → " + win.colorButtonResult
    }

    function refresh() { if (applet.refreshAll) applet.refreshAll(); else applet.refresh(); }

    Component.onCompleted: {
        var comp = Qt.createComponent(pkgUrl + "ui/main.qml");
        if (comp.status !== Component.Ready) { harnessLog.log("main.qml error: " + comp.errorString()); harness.done(); return; }
        if (scenario === "codex-notstarted") harnessFixtures.setMode("notstarted");
        applet = comp.createObject(win, { visible: false });

        if (scenario === "separator") {
            var rep = applet.fullRepresentation.createObject(panel);
            var tail = Qt.createQmlObject('import QtQuick; import QtQuick.Layouts; Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; color: "#27ae60"; radius: 4 }', panel);
            harnessLog.log("preferredRepresentation is fullRepresentation: " + (applet.preferredRepresentation === applet.fullRepresentation));
            timeline.steps = [[400, function(){ harness.snap("separator (inline in panel between two squares)"); }],
                              [450, function(){ harness.done(); }]];
            timeline.start();
            return;
        }

        var compact = applet.compactRepresentation.createObject(panel);
        Qt.createQmlObject('import QtQuick; import QtQuick.Layouts; Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; color: "#27ae60"; radius: 4; Text { anchors.centerIn: parent; text: "3"; color: "white"; font.bold: true; font.pixelSize: 20 } }', panel);
        applet.fullRepresentation.createObject(popup, { width: popup.width, height: popup.height });

        // ColorButton: exercise the Qt 6 ColorDialog API end to end.
        var cbComp = Qt.createComponent(pkgUrl + "ui/ColorButton.qml");
        if (cbComp.status !== Component.Ready) { harnessLog.log("ColorButton error: " + cbComp.errorString()); }
        else {
            var cb = cbComp.createObject(win, { x: 600, y: 270, currentColor: "#ff10a37f" });
            cb.picked.connect(function(hex) { win.colorButtonResult = "picked(" + hex + ")"; harnessLog.log("ColorButton picked " + hex); });
            var dlg = null;
            for (var i = 0; i < cb.data.length; i++) if (cb.data[i].selectedColor !== undefined) dlg = cb.data[i];
            harnessLog.log("ColorDialog found: " + (dlg !== null) + ", initial selectedColor=" + (dlg ? dlg.selectedColor : "n/a")
                           + ", options=" + (dlg ? dlg.options : "n/a"));
            if (dlg) { dlg.open(); dlg.selectedColor = Qt.rgba(1, 0.5, 0, 0.5); dlg.accept(); }
        }


        if (scenario === "codex-notstarted") {
            timeline.steps = [[1200, function(){ harness.snap("codex: windows NOT started → labels must be '-'"); }],
                              [1250, function(){ harness.done(); }]];
        } else {
            timeline.steps = [
                [150,  function(){ harness.snap("1 · update OK → green flash peak (arc bright green, track dark green)"); }],
                [1300, function(){ harness.snap("2 · steady state"); harnessFixtures.setMode("error"); win.refresh(); }],
                [1450, function(){ harness.snap("3 · failure #1 → red arc flash (no alarm yet)"); }],
                [2400, function(){ win.refresh(); }],
                [3100, function(){ harness.snap("4 · failure #2 → alarm peak (track dark red + arc bright red)"); }],
                [3800, function(){ harness.snap("5 · alarm trough (keeps blinking)"); harnessFixtures.setMode("ok"); win.refresh(); }],
                [5000, function(){ harness.snap("6 · recovered → alarm off, normal colors"); }],
                [5050, function(){ harness.done(); }]
            ];
        }
        timeline.start();
    }

    Timer {
        id: timeline
        property var steps: []
        property real t0: 0
        interval: 10; repeat: true
        onRunningChanged: if (running) t0 = Date.now()
        onTriggered: {
            var el = Date.now() - t0;
            while (steps.length && steps[0][0] <= el) { var s = steps.shift(); s[1](); }
        }
    }
}
