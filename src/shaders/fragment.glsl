precision highp float;

uniform vec2 iResolution;
uniform float iTime;
uniform float uRadius;
uniform float uNoiseAmp;
uniform float uSpeed;
uniform float uGlowIntensity;
uniform float uFogDensity;
uniform float uLightIntensity;
uniform float uCausticStrength;
uniform float uBubbleDensity;
uniform float uWaveSpeed;
uniform float uSpecularShininess;
uniform float uTunnelType;
uniform sampler2D iChannel0;
uniform float uFocalLength;
uniform float uBumpFactor;
uniform float uTunnelBend;
uniform float uCapsuleHeight;
uniform float uCapsuleRadius;
uniform vec3 uCapsuleColor;
uniform float uCapsuleShininess;
uniform float uCapsuleDiffuse;
uniform bool uAnimateBend;
uniform float uBendAnimationSpeed;
uniform float uBendAnimationAmplitude;
uniform bool uAnimateRadius;
uniform float uRadiusAnimationSpeed;
uniform float uRadiusAnimationAmplitude;
uniform float uChromaticAberrationStrength;
uniform int uNumCapsules;
uniform float uCapsuleSpacing;
uniform float uCapsuleSpeedVariation;
uniform float uCapsuleColorVariation;

#define PI 3.14159265
#define MAX_CAPSULES 10

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

// Capsule SDF
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

// Camera path with bending
vec2 path(float z) {
    float bend = uTunnelBend;
    if (uAnimateBend) {
        bend += sin(iTime * uBendAnimationSpeed) * uBendAnimationAmplitude;
    }
    return vec2(bend * sin(z * 0.5), bend * cos(z * 0.3));
}

vec3 capsuleNormal(vec3 p) {
    vec2 e = vec2(0.02, 0.0);
    // Capsule
    float capsuleTime = iTime * uSpeed;
    float capsuleRadius = uCapsuleRadius;
    float capsuleHeight = uCapsuleHeight;
    vec3 capsuleCenter = vec3(path(capsuleTime), capsuleTime);
    vec3 capsuleA = capsuleCenter + vec3(0.0, capsuleHeight * 0.5, 0.0);
    vec3 capsuleB = capsuleCenter - vec3(0.0, capsuleHeight * 0.5, 0.0);
    
    float d = sdCapsule(p, capsuleA, capsuleB, capsuleRadius);
    vec3 n = d - vec3(
        sdCapsule(p - e.xyy, capsuleA, capsuleB, capsuleRadius),
        sdCapsule(p - e.yxy, capsuleA, capsuleB, capsuleRadius),
        sdCapsule(p - e.yyx, capsuleA, capsuleB, capsuleRadius)
    );
    return normalize(n);
}

// Caustic noise simulation (used for underwater)
float caustics(vec3 p) {
    float t = iTime * 0.5;
    float n1 = fbm(p * 0.1 + vec3(t * 0.1, t * 0.05, t * 0.02));
    float n2 = fbm(p * 0.15 + vec3(t * -0.08, t * 0.1, t * 0.03));
    return (n1 * n2) * uCausticStrength * 1.5; // Increased strength
}

// Bubble simulation (used for underwater)
float bubbles(vec3 p) {
    float bub = sin(p.z * 10.0 + iTime * 2.0) * 0.5 + 0.5;
    bub *= fbm(p * 2.0 + vec3(0.0, iTime * 0.5, 0.0)) * uBubbleDensity * 1.5; // Increased density
    return bub;
}

// Distance to tunnel with perturbations
vec2 map(vec3 p) {
    float radius = uRadius;
    if (uAnimateRadius) {
        radius += sin(iTime * uRadiusAnimationSpeed) * uRadiusAnimationAmplitude;
    }
    float tunnelDist = -length(p.xy - path(p.z)) + radius;
    
    vec3 res = vec3(tunnelDist, 1.0, 0.0); // Default to tunnel

    for (int i = 0; i < MAX_CAPSULES; i++) {
        if (i >= uNumCapsules) break; // Only process active capsules

        float i_f = float(i);
        float capsuleTime = iTime * uSpeed * (1.0 + i_f * uCapsuleSpeedVariation) + i_f * uCapsuleSpacing;
        float capsuleRadius = uCapsuleRadius; // Use base radius from GUI
        float capsuleHeight = uCapsuleHeight; // Use base height from GUI
        
        vec3 capsuleCenter = vec3(path(capsuleTime), capsuleTime);
        vec3 capsuleA = capsuleCenter + vec3(0.0, capsuleHeight * 0.5, 0.0);
        vec3 capsuleB = capsuleCenter - vec3(0.0, capsuleHeight * 0.5, 0.0);
        float capsuleDist = sdCapsule(p, capsuleA, capsuleB, capsuleRadius);

        if (capsuleDist < res.x) {
            res = vec3(capsuleDist, 2.0, i_f); // Store capsule index
        }
    }
    return res.xy;
}

// Normal calculation with smoother gradients
vec3 normal(vec3 p) {
    vec3 res = map(p);
    float d = res.x;
    vec2 e = vec2(0.02, 0.0);
    vec3 n = d - vec3(
        map(p - e.xyy).x,
        map(p - e.yxy).x,
        map(p - e.yyx).x
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
    float fl = uFocalLength;
    vec3 rd = normalize(fwd + fl * (uv.x * right + uv.y * up));
    
    // Glow, adjusted for tunnel type
    float glow = 0.0;
    vec3 glowCol;
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.0);
    
    for (int i = 0; i < 100; i++) {
        vec3 p = ro + t * rd;
        vec3 res = map(p);
        float d = res.x;
        float objID = res.y;
        float objIndex = res.z;
        
        // Add glow, with bubbles for underwater only
        glow += exp(-d * 6.0) * 0.01;
        if (uTunnelType < 0.5) { // Underwater
            glow += bubbles(p) * 0.005;
        }
        
        if (d < 0.02) {
            vec3 n = normal(p);
            vec3 lightDir = normalize(vec3(0.0, 1.0, mix(-0.5, 0.5, uTunnelType))); // Different light for clouds
            
            if (objID == 2.0) { // Capsule
                // Generate capsule-specific color
                vec3 capsuleColor = uCapsuleColor;
                capsuleColor.r += sin(objIndex * 1.5 + iTime * 0.5) * uCapsuleColorVariation;
                capsuleColor.g += cos(objIndex * 2.0 + iTime * 0.5) * uCapsuleColorVariation;
                capsuleColor.b += sin(objIndex * 2.5 + iTime * 0.5) * uCapsuleColorVariation;
                capsuleColor = clamp(capsuleColor, 0.0, 1.0); // Ensure color is within range

                n = capsuleNormal(p);
                float diffuse = max(dot(n, lightDir), 0.0);
                vec3 h = normalize(lightDir - rd);
                float specular = pow(max(dot(n, h), 0.0), uCapsuleShininess);
                col = capsuleColor * diffuse * uCapsuleDiffuse + vec3(1.0) * specular;
            } else { // Tunnel
                n = bumpNormal(p, n, uBumpFactor); // Softer bumps for clouds
                
                // Base color with effects
                vec3 baseCol;
                if (uTunnelType > 1.5) { // Lava
                    float lavaNoise = fbm(p * 1.2 + vec3(0.0, 0.0, iTime * 0.4)); // Faster and more detailed noise
                    vec3 lavaColor1 = vec3(1.0, 0.4, 0.0);
                    vec3 lavaColor2 = vec3(0.9, 0.1, 0.0);
                    baseCol = mix(lavaColor1, lavaColor2, pow(lavaNoise, 2.0)); // Use pow for sharper contrast
                    baseCol *= 2.0; // Make it even brighter
                } else if (uTunnelType > 0.5) { // Clouds
                    baseCol = vec3(0.8, 0.85, 0.9);
                    float noise = 0.1 * fbm(p * 0.5);
                    baseCol *= (1.0 + noise);
                } else { // Underwater
                    baseCol = vec3(0.1, 0.3, 0.5);
                    float noise = 0.1 * fbm(p * 0.5);
                    baseCol *= (1.0 + noise);
                    baseCol += caustics(p) * 0.5; // Add white caustics
                }
                
                // Diffuse lighting
                float diffuseL = max(dot(n, lightDir), 0.0) * 0.5 * uLightIntensity + mix(0.3, 0.4, uTunnelType);
                if (uTunnelType > 1.5) { // Lava is emissive
                    diffuseL = 1.0;
                }
                col += diffuseL * baseCol;
                
                // Specular lighting
                if (uTunnelType < 1.5) {
                    vec3 h = normalize(lightDir - rd);
                    float specL = pow(max(dot(n, h), 0.0), uSpecularShininess) * 0.4 * uLightIntensity;
                    col += specL * mix(vec3(1.0, 1.0, 0.8), vec3(1.0), uTunnelType);
                }
                
                // Reflection
                if (uTunnelType < 1.5) {
                    vec3 r = reflect(rd, n);
                    vec3 reflCol = baseCol * 0.3 * (0.5 + 0.5 * fbm(r * 0.5));
                    col = mix(col, reflCol, mix(0.3, 0.2, uTunnelType));
                }
            }
            
            break;
        }
        
        t += d * 0.8;
    }
    
    // Add glow
    if (uTunnelType > 1.5) { // Lava glow
        glowCol = vec3(1.0, 0.2, 0.0) * uGlowIntensity;
    } else if (uTunnelType > 0.5) { // Clouds
        glowCol = vec3(0.8, 0.85, 0.9) * uGlowIntensity;
    } else { // Underwater
        glowCol = vec3(0.1, 0.3, 0.5) * uGlowIntensity;
    }
    col += glowCol * glow;
    
    // Fog effect tinted by base color
    float fogDensity = uFogDensity;
    if (uTunnelType > 0.5 && uTunnelType < 1.5) { // Clouds
        fogDensity *= 2.0;
    }
    vec3 fogCol;
    if (uTunnelType > 0.5 && uTunnelType < 1.5) { // Clouds
        fogCol = vec3(0.8, 0.85, 0.9);
    } else { // Underwater
        fogCol = vec3(0.1, 0.3, 0.5);
    }
    col = mix(col, fogCol, 1.0 - exp(-t * fogDensity));

    // Scene-wide noise
    col += (hash(uv + iTime) - 0.5) * 0.1;

    // Chromatic Aberration
    float distFromCenter = length(uv);
    vec3 chromaticShift = vec3(distFromCenter * uChromaticAberrationStrength);
    col.r += chromaticShift.r;
    col.g += chromaticShift.g;
    col.b += chromaticShift.b;
    
    // Gamma correction
    col = pow(col, vec3(1.0 / 2.2));
    
    // Output
    gl_FragColor = vec4(col, 1.0);
}