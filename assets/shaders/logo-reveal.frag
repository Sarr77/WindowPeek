#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float mode;
    float imageWidth;
    float imageHeight;
};
layout(binding = 1) uniform sampler2D source;

float noise(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 imageSize = vec2(imageWidth, imageHeight);
    float p = clamp(phase, 0.0, 1.0);
    if (p <= 0.0) { fragColor = vec4(0.0); return; }
    float mask = p;
    if (p >= 1.0 || mode < 0.5) {
        mask = 1.0;
    } else if (mode < 1.5) { // Pixels: shuffled square fragments reveal the live frame.
        vec2 grid = max(vec2(1.0), ceil(imageSize / 9.0));
        float rank = noise(floor(uv * grid));
        mask = smoothstep(rank * 0.88, rank * 0.88 + 0.12, p);
    } else if (mode < 2.5) { // Scatter: fragments drift, rotate and grow into place.
        vec2 grid = max(vec2(1.0), ceil(imageSize / 24.0));
        vec2 cell = floor(uv * grid);
        float seed = noise(cell);
        float t = smoothstep(seed * 0.35, seed * 0.35 + 0.65, p);
        vec2 local = fract(uv * grid) - 0.5;
        local -= vec2(seed - 0.5, noise(cell + 17.0) - 0.5) * (1.0-t) * 0.8;
        float angle = (seed - 0.5) * (1.0-t) * 1.2;
        local = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * local;
        local = local / mix(0.12, 1.0, t) + 0.5;
        mask = step(0.0,local.x) * step(local.x,1.0) * step(0.0,local.y) * step(local.y,1.0) * t;
        uv = (cell + clamp(local, 0.0, 1.0)) / grid;
    } else if (mode < 3.5) { // Left-to-right wipe.
        mask = 1.0 - smoothstep(p * 1.08 - 0.08, p * 1.08, uv.x);
    } else if (mode < 4.5) { // Horizontal blinds.
        float stripe = fract(uv.y * max(1.0, ceil(imageSize.y / 12.0)));
        mask = 1.0 - smoothstep(p * 1.08 - 0.08, p * 1.08, stripe);
    } else if (mode < 5.5) { // A circular iris, corrected for the artwork aspect.
        vec2 ratio = vec2(max(0.01, imageSize.x / max(1.0,imageSize.y)), 1.0);
        float radius = length((uv-0.5) * ratio) * 2.0 / length(ratio);
        mask = 1.0 - smoothstep(p * 1.06 - 0.06, p * 1.06, radius);
    }
    // One texture sample, premultiplied alpha preserved for transparent artwork.
    fragColor = texture(source, uv) * mask * qt_Opacity;
}
