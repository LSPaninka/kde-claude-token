.pragma library

// Abreviaturas de los días en español (getDay(): 0 = Domingo ... 6 = Sábado)
var DIAS = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];

function two(n) {
    return (n < 10 ? "0" : "") + n;
}

// "hh:mm"
function fmtHM(d) {
    if (!d || isNaN(d.getTime())) return "--:--";
    return two(d.getHours()) + ":" + two(d.getMinutes());
}

// "ddd hh:mm"  (ddd = tres primeras letras del día en español)
function fmtDddHM(d) {
    if (!d || isNaN(d.getTime())) return "--- --:--";
    return DIAS[d.getDay()] + " " + fmtHM(d);
}

// "dd/mm hh:mm"
function fmtFull(d) {
    if (!d || isNaN(d.getTime())) return "--/-- --:--";
    return two(d.getDate()) + "/" + two(d.getMonth() + 1) + " " + fmtHM(d);
}

// "dd/mm" a partir de una fecha o de una cadena ISO
function fmtDM(x) {
    var d = (x instanceof Date) ? x : new Date(x);
    if (!d || isNaN(d.getTime())) return "--/--";
    return two(d.getDate()) + "/" + two(d.getMonth() + 1);
}

// Tiempo restante legible a partir de milisegundos: "1d 4h", "3h 12m", "8m"
function fmtRemaining(ms) {
    if (ms === undefined || ms === null || isNaN(ms) || ms <= 0) return "0m";
    var s = Math.floor(ms / 1000);
    var d = Math.floor(s / 86400); s -= d * 86400;
    var h = Math.floor(s / 3600);  s -= h * 3600;
    var m = Math.floor(s / 60);
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}

// Convierte un objeto color de QML en cadena hexadecimal #AARRGGBB
function colorToHex(c) {
    function h(x) {
        var s = Math.round(x * 255).toString(16);
        return s.length < 2 ? "0" + s : s;
    }
    return "#" + h(c.a) + h(c.r) + h(c.g) + h(c.b);
}
