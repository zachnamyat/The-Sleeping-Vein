// tools/clean_alpha.js
//
// LibreSprite (JavaScript / V8) script.
// Replaces the background of a Gemini-generated sprite with transparency,
// using the *actual* corner-sampled background color. Avoids the tolerance-
// tuning problem we hit with sharp/Pillow chroma-key by measuring the real
// background color first, then keying everything within a tight color-
// distance from it.
//
// Usage (via tools/clean_sprite.ps1):
//   libresprite.exe --batch INPUT.png --script clean_alpha.js --save-as OUT.png

var TOLERANCE = 40;                  // per-channel RGB distance
var TOLERANCE_SQ = TOLERANCE * TOLERANCE;

function rgb(px) {
    return [
        app.pixelColor.rgbaR(px),
        app.pixelColor.rgbaG(px),
        app.pixelColor.rgbaB(px),
    ];
}

function median(arr) {
    var sorted = arr.slice().sort(function (a, b) { return a - b; });
    return sorted[Math.floor(sorted.length / 2)];
}

function cleanImage(image) {
    var w = image.width;
    var h = image.height;

    // Sample 8 perimeter points (4 corners + 4 edge midpoints) and take the
    // median of each channel as the background color. Median is robust if the
    // subject happens to reach one corner.
    var samplePts = [
        [0, 0], [w - 1, 0], [0, h - 1], [w - 1, h - 1],
        [Math.floor(w / 2), 0], [Math.floor(w / 2), h - 1],
        [0, Math.floor(h / 2)], [w - 1, Math.floor(h / 2)],
    ];
    var rs = [], gs = [], bs = [];
    for (var i = 0; i < samplePts.length; i++) {
        var s = rgb(image.getPixel(samplePts[i][0], samplePts[i][1]));
        rs.push(s[0]); gs.push(s[1]); bs.push(s[2]);
    }
    var TR = median(rs);
    var TG = median(gs);
    var TB = median(bs);

    console.log("clean_alpha: " + w + "x" + h
        + "  bg=rgb(" + TR + "," + TG + "," + TB + ")  tol=" + TOLERANCE);

    var clearColor = app.pixelColor.rgba(0, 0, 0, 0);
    var cleared = 0;
    for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
            var px = image.getPixel(x, y);
            var r = app.pixelColor.rgbaR(px);
            var g = app.pixelColor.rgbaG(px);
            var b = app.pixelColor.rgbaB(px);
            var dr = r - TR;
            var dg = g - TG;
            var db = b - TB;
            if (dr * dr + dg * dg + db * db < TOLERANCE_SQ) {
                image.putPixel(x, y, clearColor);
                cleared++;
            }
        }
    }
    console.log("clean_alpha: cleared " + cleared + "/" + (w * h) + " px ("
        + (100 * cleared / (w * h)).toFixed(1) + "%)");
}

var sprite = app.activeSprite;
if (!sprite) {
    console.log("clean_alpha: ERROR — no active sprite");
} else {
    for (var li = 0; li < sprite.layerCount; li++) {
        var layer = sprite.layer(li);
        for (var fi = 0; fi < sprite.frameCount; fi++) {
            var cel = layer.cel(fi);
            if (cel && cel.image) {
                cleanImage(cel.image);
            }
        }
    }
}
