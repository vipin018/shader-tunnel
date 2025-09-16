precision highp float;

uniform vec2 iResolution;
uniform float iTime;
uniform float uRadius;
uniform float uNoiseAmp;
uniform float uSpeed;
uniform float uGlowIntensity;
uniform vec3 uWaterColor;
uniform float uFogDensity;
uniform float uLightIntensity;
uniform float uCausticStrength;
uniform float uBubbleDensity;
uniform sampler2D iChannel0;

#define PI 3.14159265

// Noise function for water-like randomness
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec3 p) {
    vec2 i = floor(p.xy + p.z);
    vec2 f = fract(p.xy);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    vec3 shift = vec3(100.0);
    for (int i = 0; i < 6; ++i) {
        v += a * noise(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// Simple caustic noise simulation
float caustics(vec3 p) {
    float t = iTime * 0.5;
    float n1 = fbm(p * 0.1 + vec3(t * 0.1, t * 0.05, t * 0.02));
    float n2 = fbm(p * 0.15 + vec3(t * -0.08, t * 0.1, t * 0.03));
    return (n1 * n2) * uCausticStrength * 0.5;
}

// Bubble simulation using noise
float bubbles(vec3 p) {
    float bub = sin(p.z * 10.0 + iTime * 2.0) * 0.5 + 0.5;
    bub *= fbm(p * 2.0 + vec3(0.0, iTime * 0.5, 0.0)) * uBubbleDensity;
    return bub;
}

// Camera path
vec2 path(float z) {
    return vec2(0.5 * sin(z * 0.5), 0.5 * sin(z * 0.3));
}

// Distance to tunnel with water-like perturbations
float map(vec3 p) {
    float d = -length(p.xy - path(p.z)) + uRadius;
    d += uNoiseAmp * fbm(p * 0.3 + iTime * 0.1);
    return d;
}

// Normal calculation with smoother gradients
vec3 normal(vec3 p) {
    float d = map(p);
    vec2 e = vec2(0.02, 0.0);
    vec3 n = d - vec3(
        map(p - e.xyy),
        map(p - e.yxy),
        map(p - e.yyx)
    );
    return normalize(n);
}

// Water-like bump effect
float bumpFunction(vec3 p) {
    float n = fbm(p * 1.0 + iTime * 0.2);
    return n * n * 0.3;
}

// Modified bump normal for water-like surface
vec3 bumpNormal(vec3 p, vec3 n, float bumpFactor) {
    vec3 e = vec3(0.02, 0.0, 0.0);
    float f = bumpFunction(p);
    float fx = bumpFunction(p - e.xyy);
    float fy = bumpFunction(p - e.yxy);
    float fz = bumpFunction(p - e.yyx);
    
    float fx2 = bumpFunction(p + e.xyy);
    float fy2 = bumpFunction(p + e.yxy);
    float fz2 = bumpFunction(p + e.yyx);
    
    vec3 grad = (vec3(fx - fx2, fy - fy2, fz - fz2)) / (e.x * 2.0);
    grad -= n * dot(n, grad);
    return normalize(n + grad * bumpFactor);
}

void main() {
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    
    // Camera setup with adjustable speed
    float vel = iTime * uSpeed;
    vec3 ro = vec3(path(vel - 1.0), vel - 1.0);
    vec3 ta = vec3(path(vel), vel);
    
    // Ray direction
    vec3 fwd = normalize(ta - ro);
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 right = cross(fwd, up);
    up = cross(right, fwd);
    float fl = 1.2;
    vec3 rd = normalize(fwd + fl * (uv.x * right + uv.y * up));
    
    // Underwater glow
    float glow = 0.0;
    vec3 glowCol = uWaterColor * uGlowIntensity;
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.0);
    
    for (int i = 0; i < 100; i++) {
        vec3 p = ro + t * rd;
        float d = map(p);
        
        // Add soft glow with bubbles
        glow += exp(-d * 6.0) * 0.01 + bubbles(p) * 0.005;
        
        if (d < 0.02) {
            vec3 n = normal(p);
            vec3 lightDir = normalize(vec3(0.0, 1.0, -0.5));
            n = bumpNormal(p, n, 0.15);
            
            // Emphasize water color
            vec3 baseCol = uWaterColor;
            baseCol += 0.1 * fbm(p * 0.5) * uWaterColor;
            baseCol += caustics(p) * uWaterColor * 0.5;
            
            // Diffuse lighting
            float diffuseL = max(dot(n, lightDir), 0.0) * 0.5 * uLightIntensity + 0.3;
            col += diffuseL * baseCol;
            
            // Specular for water shimmer
            vec3 h = normalize(lightDir - rd);
            float specL = pow(max(dot(n, h), 0.0), 64.0) * 0.4 * uLightIntensity;
            col += specL * vec3(1.0, 1.0, 0.8);
            
            // Reflection for watery surface
            vec3 r = reflect(rd, n);
            vec3 reflCol = uWaterColor * 0.3 * (0.5 + 0.5 * fbm(r * 0.5));
            col = mix(col, reflCol, 0.3);
            
            break;
        }
        
        t += d * 0.8;
    }
    
    // Add underwater glow
    col += glowCol * glow;
    
    // Fog effect tinted by water color
    vec3 fogCol = uWaterColor * 0.5;
    col = mix(col, fogCol, 1.0 - exp(-t * uFogDensity));
    
    // Gamma correction
    col = pow(col, vec3(1.0 / 2.2));
    
    // Output
    gl_FragColor = vec4(col, 1.0);
}