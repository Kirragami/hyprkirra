#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float yaw;
    float tilt;
    float px;
};

layout(binding = 1) uniform sampler2D src;

vec2 mapUV(vec3 view, float ct, float st, float cy, float sy) {
    float y1 = view.y * ct + view.z * st;
    float z1 = -view.y * st + view.z * ct;
    float mx = view.x * cy - z1 * sy;
    float mz = view.x * sy + z1 * cy;
    float lon = atan(mx, mz);
    float lat = asin(clamp(y1, -1.0, 1.0));
    return vec2(fract(lon * 0.159154943 + 0.5), clamp(0.5 - lat * 0.318309886, 0.0, 1.0));
}

vec4 sampleMap(vec2 uv, float maxLod) {
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    float span = max(length(dx * vec2(2048.0, 1024.0)), length(dy * vec2(2048.0, 1024.0)));
    float lod = clamp(log2(max(span, 1.0)), 0.0, maxLod);
    return textureLod(src, uv, lod);
}

void main() {
    vec2 p = vec2(qt_TexCoord0.x * 2.0 - 1.0, 1.0 - qt_TexCoord0.y * 2.0);
    float r = length(p);
    float aa = max(fwidth(r), px * 0.9);
    float cover = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
    if (cover < 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    float rc = min(r, 0.9999);
    float z = sqrt(max(0.0, 1.0 - rc * rc));

    float ct = cos(tilt);
    float st = sin(tilt);
    float cy = cos(yaw);
    float sy = sin(yaw);

    vec4 backL = sampleMap(mapUV(vec3(p.x, p.y, -z), ct, st, cy, sy), 0.7);
    vec4 frontL = sampleMap(mapUV(vec3(p.x, p.y, z), ct, st, cy, sy), 0.35);

    float fCover = smoothstep(0.03, 0.16, frontL.a);
    float bCover = smoothstep(0.03, 0.16, backL.a) * 0.36;

    vec3 rgb = backL.rgb * (0.16 + 0.18 * z);
    float a = bCover;
    rgb = mix(rgb, frontL.rgb * (0.38 + 0.62 * z), fCover);
    a = a * (1.0 - fCover) + frontL.a;

    float rimW = max(px * 1.4, aa * 1.7);
    float rim = smoothstep(1.0 - rimW * 2.2, 1.0 - rimW * 0.5, r)
            * (1.0 - smoothstep(1.0 - rimW * 0.2, 1.0 + aa, r));
    rgb = mix(rgb, vec3(0.902), rim);
    a = max(a, rim * 0.62);

    fragColor = vec4(rgb, a * cover) * qt_Opacity;
}
