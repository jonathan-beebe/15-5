#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 cell = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(
        mix(hash(cell), hash(cell + float2(1, 0)), u.x),
        mix(hash(cell + float2(0, 1)), hash(cell + float2(1, 1)), u.x),
        u.y
    );
}

/// Layered noise. Two layers keep it smooth, since each added layer adds finer, wispier detail.
/// Rotating the second layer hides the axis-aligned grid.
static float fbm(float2 p) {
    const float2x2 rotation = float2x2(0.8, 0.6, -0.6, 0.8);
    float value = 0.0;
    float amplitude = 0.5;
    for (int layer = 0; layer < 2; layer++) {
        value += amplitude * noise(p);
        p = rotation * p * 2.0;
        amplitude *= 0.5;
    }
    return value;
}

/// Stable across a wide coordinate range, unlike the sine hash above, so large displays show no
/// repeating pattern in the grain.
static float grainHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Peak brightness change from the grain.
constant float grainAmount = 0.02;

/// Domain warping: noise displaces the input to more noise, which folds the pattern into
/// currents. `time` moves each layer at its own rate, so the currents drift through each other.
[[stitchable]] half4 fluidWash(
    float2 position,
    half4 color,
    float2 size,
    float time,
    half4 deep,
    half4 middle,
    half4 bright,
    float softness
) {
    float2 p = position / max(size.x, size.y) * 1.4;

    float2 q = float2(
        fbm(p + float2(0.0, 0.0) + time * 0.7),
        fbm(p + float2(5.2, 1.3) - time * 0.5)
    );
    float2 r = float2(
        fbm(p + 1.8 * q + float2(1.7, 9.2) + time * 0.4),
        fbm(p + 1.8 * q + float2(8.3, 2.8) - time * 0.3)
    );
    float f = fbm(p + 1.8 * r);

    half3 result = mix(deep.rgb, middle.rgb, half(smoothstep(0.15, 0.6, f)));
    result = mix(result, bright.rgb, half(smoothstep(0.2, 0.7, length(q) * 0.75)));
    // Pulls every color toward the palette's average, which narrows the bright-to-dark range.
    half3 average = (deep.rgb + middle.rgb + bright.rgb) / 3.0;
    result = mix(result, average, half(softness));

    // Depends on position alone, so the grain stays still while the color flows beneath it.
    result += half((grainHash(position) * 2.0 - 1.0) * grainAmount);
    return half4(result, 1.0);
}
