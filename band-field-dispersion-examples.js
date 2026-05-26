/*
Static examples for per-band rainbow dispersion.

Change SELECTED_CONFIG at the bottom.

R/G still control band displacement:
  x offset = (R - 0.5) * xAmplitudePx
  y offset = (G - 0.5) * yAmplitudePx

dispersionPx controls traced rainbow spread in pixels:
  0   = no rainbow dispersion
  20  = moderate rainbow
  80+ = exaggerated rainbow
  negative values reverse the rainbow order

rainbowBrightness controls spectral colour gain:
  1   = neutral brightness
  2-4 = more vibrant rainbow aesthetic
  8   = clamped maximum
*/

var CONFIGS = {
  noDispersionNeutral: {
    enabled: true,
    xAmplitudePx: 35,
    yAmplitudePx: 0,
    layers: [{
      axis: "vertical",
      blendMode: "over",
      opacity: 1,
      bands: [{
        center: 0,
        halfWidth: 2,
        featherW: 0,
        centerL: 0,
        halfLength: 2,
        featherL: 0,
        alpha: 1,
        dispersionPx: 0,
        rainbowBrightness: 1,
        gradient: [[0, [0.5, 0.5, 0.5, 1]], [1, [0.5, 0.5, 0.5, 1]]],
        gradMode: "width"
      }]
    }]
  },

  centeredModerateRainbow: {
    enabled: true,
    xAmplitudePx: 35,
    yAmplitudePx: 0,
    layers: [{
      axis: "vertical",
      blendMode: "over",
      opacity: 1,
      bands: [
        {
          center: 0,
          halfWidth: 2,
          featherW: 0,
          centerL: 0,
          halfLength: 2,
          featherL: 0,
          alpha: 1,
          dispersionPx: 0,
          rainbowBrightness: 1,
          gradient: [[0, [0.5, 0.5, 0.5, 1]], [1, [0.5, 0.5, 0.5, 1]]],
          gradMode: "width"
        },
        {
          center: 0,
          halfWidth: 0.35,
          featherW: 0.1,
          centerL: 0,
          halfLength: 1.2,
          featherL: 0.02,
          alpha: 1,
          dispersionPx: 28,
          rainbowBrightness: 2.5,
          gradient: [[0, [0.5, 0.5, 0.5, 1]], [1, [0.5, 0.5, 0.5, 1]]],
          gradMode: "width"
        }
      ]
    }]
  },

  reversedRainbow: {
    enabled: true,
    xAmplitudePx: 35,
    yAmplitudePx: 0,
    layers: [{
      axis: "vertical",
      blendMode: "over",
      opacity: 1,
      bands: [
        {
          center: 0,
          halfWidth: 2,
          featherW: 0,
          centerL: 0,
          halfLength: 2,
          featherL: 0,
          alpha: 1,
          dispersionPx: 0,
          rainbowBrightness: 1,
          gradient: [[0, [0.5, 0.5, 0.5, 1]], [1, [0.5, 0.5, 0.5, 1]]],
          gradMode: "width"
        },
        {
          center: 0,
          halfWidth: 0.35,
          featherW: 0.1,
          centerL: 0,
          halfLength: 1.2,
          featherL: 0.02,
          alpha: 1,
          dispersionPx: -28,
          rainbowBrightness: 2.5,
          gradient: [[0, [0.5, 0.5, 0.5, 1]], [1, [0.5, 0.5, 0.5, 1]]],
          gradMode: "width"
        }
      ]
    }]
  },

  exaggeratedPrism: {
    enabled: true,
    xAmplitudePx: 55,
    yAmplitudePx: 25,
    layers: [{
      axis: "vertical",
      blendMode: "over",
      opacity: 1,
      bands: [
        {
          center: 0,
          halfWidth: 2,
          featherW: 0,
          centerL: 0,
          halfLength: 2,
          featherL: 0,
          alpha: 1,
          dispersionPx: 0,
          rainbowBrightness: 1,
          gradient: [[0, [0.5, 0.5, 0.5, 1]], [1, [0.5, 0.5, 0.5, 1]]],
          gradMode: "width"
        },
        {
          center: -0.35,
          halfWidth: 0.18,
          featherW: 0.08,
          centerL: 0,
          halfLength: 1.2,
          featherL: 0.02,
          alpha: 1,
          dispersionPx: 90,
          rainbowBrightness: 4,
          gradient: [[0, [0.0, 0.5, 0.5, 1]], [1, [1.0, 0.5, 0.5, 1]]],
          gradMode: "width"
        },
        {
          center: 0.35,
          halfWidth: 0.18,
          featherW: 0.08,
          centerL: 0,
          halfLength: 1.2,
          featherL: 0.02,
          alpha: 1,
          dispersionPx: -90,
          rainbowBrightness: 4,
          gradient: [[0, [1.0, 0.5, 0.5, 1]], [1, [0.0, 0.5, 0.5, 1]]],
          gradMode: "width"
        }
      ]
    }]
  }
};

var SELECTED_CONFIG = "exaggeratedPrism";

outputState = {
  bands: CONFIGS[SELECTED_CONFIG]
};
