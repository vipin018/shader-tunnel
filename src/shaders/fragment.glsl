precision highp float;

uniform vec2 iResolution;
uniform float iTime;
uniform float uRadius;
uniform float uNoiseAmp;
uniform float uSpeed;
uniform float uGlowIntensity;
uniform vec3 uBaseColor;
uniform float uFogDensity;
uniform float uLightIntensity;
uniform float uCausticStrength;
uniform float uBubbleDensity;
uniform float uWaveSpeed;
uniform float uSpecularShininess;
uniform float uTunnelType;
uniform sampler2D iChannel0;

#define PI 3.14159265

// Noise function for randomness
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

// Caustic noise simulation (used for underwater)
float caustics(vec3 p) {
    float t = iTime * 0.5;
    float n1 = fbm(p * 0.1 + vec3(t * 0.1, t * 0.05, t * 0.02));
    float n2 = fbm(p * 0.15 + vec3(t * -0.08, t * 0.1, t * 0.03));
    return (n1 * n2) * uCausticStrength * 0.5;
}

// Bubble simulation (used for underwater)
float bubbles(vec3 p) {
    float bub = sin(p.z * 10.0 + iTime * 2.0) * 0.5 + 0.5;
    bub *= fbm(p * 2.0 + vec3(0.0, iTime * 0.5, 0.0)) * uBubbleDensity;
    return bub;
}

// Camera path
vec2 path(float z) {
    return vec2(0.5 * sin(z * 0.5), 0.5 * sin(z * 0.3));
}

// Distance to tunnel with perturbations
float map(vec3 p) {
    float d = -length(p.xy - path(p.z)) + uRadius;
    // Adjust noise amplitude for clouds (softer) vs underwater (sharper)
    float noiseScale = mix(uNoiseAmp, uNoiseAmp * 1.5, uTunnelType);
    d += noiseScale * fbm(p * mix(0.3, 0.5, uTunnelType) + iTime * uWaveSpeed);
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

// Bump effect
float bumpFunction(vec3 p) {
    float n = fbm(p * mix(1.0, 0.8, uTunnelType) + iTime * uWaveSpeed);
    return n * n * mix(0.3, 0.5, uTunnelType); // Stronger bumps for clouds
}

// Modified bump normal
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
    
    // Glow, adjusted for tunnel type
    float glow = 0.0;
    vec3 glowCol = uBaseColor * uGlowIntensity;
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.0);
    
    for (int i = 0; i < 100; i++) {
        vec3 p = ro + t * rd;
        float d = map(p);
        
        // Add glow, with bubbles for underwater only
        glow += exp(-d * 6.0) * 0.01;
        if (uTunnelType < 0.5) { // Underwater
            glow += bubbles(p) * 0.005;
        }
        
        if (d < 0.02) {
            vec3 n = normal(p);
            vec3 lightDir = normalize(vec3(0.0, 1.0, mix(-0.5, 0.5, uTunnelType))); // Different light for clouds
            n = bumpNormal(p, n, mix(0.15, 0.1, uTunnelType)); // Softer bumps for clouds
            
            // Base color with effects
            vec3 baseCol = uBaseColor;
            baseCol += 0.1 * fbm(p * 0.5) * uBaseColor;
            if (uTunnelType < 0.5) { // Underwater: add caustics
                baseCol += caustics(p) * uBaseColor * 0.5;
            }
            
            // Diffuse lighting
            float diffuseL = max(dot(n, lightDir), 0.0) * 0.5 * uLightIntensity + mix(0.3, 0.4, uTunnelType);
            col += diffuseL * baseCol;
            
            // Specular lighting
            vec3 h = normalize(lightDir - rd);
            float specL = pow(max(dot(n, h), 0.0), uSpecularShininess) * 0.4 * uLightIntensity;
            col += specL * mix(vec3(1.0, 1.0, 0.8), vec3(1.0), uTunnelType); // Whiter specular for clouds
            
            // Reflection
            vec3 r = reflect(rd, n);
            vec3 reflCol = uBaseColor * 0.3 * (0.5 + 0.5 * fbm(r * 0.5));
            col = mix(col, reflCol, mix(0.3, 0.2, uTunnelType));
            
            break;
        }
        
        t += d * 0.8;
    }
    
    // Add glow
    col += glowCol * glow;
    
    // Fog effect tinted by base color
    vec3 fogCol = uBaseColor * mix(0.5, 0.8, uTunnelType);
    col = mix(col, fogCol, 1.0 - exp(-t * uFogDensity));
    
    // Gamma correction
    col = pow(col, vec3(1.0 / 2.2));
    
    // Output
    gl_FragColor = vec4(col, 1.0);
}