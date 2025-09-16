import { GUI } from 'lil-gui';

async function loadShaderFile(url) {
    const response = await fetch(url);
    return await response.text();
}

async function main() {
    const canvas = document.getElementById('canvas');
    const gl = canvas.getContext('webgl2') || gl.getContext('webgl');
    
    if (!gl) {
        alert('WebGL not supported');
        return;
    }

    // Load shader sources
    const vertexShaderSource = await loadShaderFile('src/shaders/vertex.glsl');
    const fragmentShaderSource = await loadShaderFile('src/shaders/fragment.glsl');

    // Create shader function
    function createShader(gl, type, source) {
        const shader = gl.createShader(type);
        gl.shaderSource(shader, source);
        gl.compileShader(shader);
        
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            console.error('Error compiling shader:', gl.getShaderInfoLog(shader));
            gl.deleteShader(shader);
            return null;
        }
        
        return shader;
    }

    // Create program function
    function createProgram(gl, vertexShader, fragmentShader) {
        const program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        gl.linkProgram(program);
        
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
            console.error('Error linking program:', gl.getProgramInfoLog(program));
            gl.deleteProgram(program);
            return null;
        }
        
        return program;
    }

    // Create shaders and program
    const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexShaderSource);
    const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource);
    const program = createProgram(gl, vertexShader, fragmentShader);

    // Get uniform locations
    const iResolutionLocation = gl.getUniformLocation(program, 'iResolution');
    const iTimeLocation = gl.getUniformLocation(program, 'iTime');
    const uRadiusLocation = gl.getUniformLocation(program, 'uRadius');
    const uNoiseAmpLocation = gl.getUniformLocation(program, 'uNoiseAmp');
    const uSpeedLocation = gl.getUniformLocation(program, 'uSpeed');
    const uGlowIntensityLocation = gl.getUniformLocation(program, 'uGlowIntensity');
    const uFogDensityLocation = gl.getUniformLocation(program, 'uFogDensity');
    const uLightIntensityLocation = gl.getUniformLocation(program, 'uLightIntensity');
    const uCausticStrengthLocation = gl.getUniformLocation(program, 'uCausticStrength');
    const uBubbleDensityLocation = gl.getUniformLocation(program, 'uBubbleDensity');
    const uWaveSpeedLocation = gl.getUniformLocation(program, 'uWaveSpeed');
    const uSpecularShininessLocation = gl.getUniformLocation(program, 'uSpecularShininess');
    const uTunnelTypeLocation = gl.getUniformLocation(program, 'uTunnelType');
    const uFocalLengthLocation = gl.getUniformLocation(program, 'uFocalLength');
    const uBumpFactorLocation = gl.getUniformLocation(program, 'uBumpFactor');
    const uTunnelBendLocation = gl.getUniformLocation(program, 'uTunnelBend');
    const uCapsuleHeightLocation = gl.getUniformLocation(program, 'uCapsuleHeight');
    const uCapsuleRadiusLocation = gl.getUniformLocation(program, 'uCapsuleRadius');
    const uCapsuleColorLocation = gl.getUniformLocation(program, 'uCapsuleColor');
    const uCapsuleShininessLocation = gl.getUniformLocation(program, 'uCapsuleShininess');
    const uCapsuleDiffuseLocation = gl.getUniformLocation(program, 'uCapsuleDiffuse');
    const uAnimateBendLocation = gl.getUniformLocation(program, 'uAnimateBend');
    const uBendAnimationSpeedLocation = gl.getUniformLocation(program, 'uBendAnimationSpeed');
    const uBendAnimationAmplitudeLocation = gl.getUniformLocation(program, 'uBendAnimationAmplitude');
    const uAnimateRadiusLocation = gl.getUniformLocation(program, 'uAnimateRadius');
    const uRadiusAnimationSpeedLocation = gl.getUniformLocation(program, 'uRadiusAnimationSpeed');
    const uRadiusAnimationAmplitudeLocation = gl.getUniformLocation(program, 'uRadiusAnimationAmplitude');
    const uChromaticAberrationStrengthLocation = gl.getUniformLocation(program, 'uChromaticAberrationStrength');
    const uNumCapsulesLocation = gl.getUniformLocation(program, 'uNumCapsules');
    const uCapsuleSpacingLocation = gl.getUniformLocation(program, 'uCapsuleSpacing');
    const uCapsuleSpeedVariationLocation = gl.getUniformLocation(program, 'uCapsuleSpeedVariation');
    const uCapsuleColorVariationLocation = gl.getUniformLocation(program, 'uCapsuleColorVariation');

    // Create buffer for full-screen quad
    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
        -1, -1,
         1, -1,
        -1,  1,
        -1,  1,
         1, -1,
         1,  1
    ]), gl.STATIC_DRAW);

    // Get attribute location
    const positionLocation = gl.getAttribLocation(program, 'position');

    // GUI setup
    const params = {
        radius: 1.5,
        noiseAmplitude: 0.4,
        speed: 1.0,
        glowIntensity: 1.0,
        fogDensity: 0.05,
        lightIntensity: 1.0,
        causticStrength: 1.0,
        bubbleDensity: 1.0,
        waveSpeed: 0.1,
        specularShininess: 64.0,
        tunnelType: 'Underwater',
        focalLength: 1.2,
        bumpFactor: 0.15,
        tunnelBend: 0.5,
        capsuleHeight: 1.0,
        capsuleRadius: 0.3,
        capsuleColor: [200, 200, 200],
        capsuleShininess: 256.0,
        capsuleDiffuse: 0.8,
        animateBend: true,
        bendAnimationSpeed: 0.5,
        bendAnimationAmplitude: 0.5,
        animateRadius: true,
        radiusAnimationSpeed: 0.5,
        radiusAnimationAmplitude: 0.2,
        chromaticAberrationStrength: 0.01,
        numCapsules: 3,
        capsuleSpacing: 5.0,
        capsuleSpeedVariation: 0.2,
        capsuleColorVariation: 0.5
    };

    const gui = new GUI();
    const tunnelFolder = gui.addFolder('Tunnel');
    tunnelFolder.add(params, 'tunnelType', ['Underwater', 'Clouds', 'Lava']).name('Type').onChange(() => updateUniforms());
    tunnelFolder.add(params, 'radius', 0.5, 3.0, 0.1).name('Radius').onChange(() => updateUniforms());
    tunnelFolder.add(params, 'tunnelBend', 0.0, 2.0, 0.1).name('Bend').onChange(() => updateUniforms());
    tunnelFolder.add(params, 'speed', 0.1, 2.0, 0.1).name('Speed').onChange(() => updateUniforms());

    const animationFolder = tunnelFolder.addFolder('Animation');
    animationFolder.add(params, 'animateBend').name('Animate Bend').onChange(() => updateUniforms());
    animationFolder.add(params, 'bendAnimationSpeed', 0.1, 2.0, 0.1).name('Bend Speed').onChange(() => updateUniforms());
    animationFolder.add(params, 'bendAnimationAmplitude', 0.1, 1.0, 0.1).name('Bend Amplitude').onChange(() => updateUniforms());
    animationFolder.add(params, 'animateRadius').name('Animate Radius').onChange(() => updateUniforms());
    animationFolder.add(params, 'radiusAnimationSpeed', 0.1, 2.0, 0.1).name('Radius Speed').onChange(() => updateUniforms());
    animationFolder.add(params, 'radiusAnimationAmplitude', 0.1, 1.0, 0.1).name('Radius Amplitude').onChange(() => updateUniforms());

    const effectsFolder = gui.addFolder('Effects');
    effectsFolder.add(params, 'noiseAmplitude', 0.0, 1.0, 0.01).name('Noise Amplitude').onChange(() => updateUniforms());
    effectsFolder.add(params, 'waveSpeed', 0.05, 0.5, 0.01).name('Wave Speed').onChange(() => updateUniforms());
    effectsFolder.add(params, 'fogDensity', 0.01, 0.2, 0.01).name('Fog Density').onChange(() => updateUniforms());
    effectsFolder.add(params, 'glowIntensity', 0.0, 2.0, 0.1).name('Glow Intensity').onChange(() => updateUniforms());

    const lightingFolder = gui.addFolder('Lighting');
    lightingFolder.add(params, 'lightIntensity', 0.5, 2.0, 0.1).name('Light Intensity').onChange(() => updateUniforms());
    lightingFolder.add(params, 'specularShininess', 10.0, 100.0, 1.0).name('Tunnel Shininess').onChange(() => updateUniforms());
    lightingFolder.add(params, 'bumpFactor', 0.0, 0.5, 0.01).name('Bump Factor').onChange(() => updateUniforms());

    const underwaterFolder = gui.addFolder('Underwater');
    underwaterFolder.add(params, 'causticStrength', 0.0, 2.0, 0.1).name('Caustic Strength').onChange(() => updateUniforms());
    underwaterFolder.add(params, 'bubbleDensity', 0.0, 2.0, 0.1).name('Bubble Density').onChange(() => updateUniforms());

    const cameraFolder = gui.addFolder('Camera');
    cameraFolder.add(params, 'focalLength', 0.5, 3.0, 0.1).name('Focal Length').onChange(() => updateUniforms());

    const capsuleFolder = gui.addFolder('Capsule');
    capsuleFolder.add(params, 'capsuleHeight', 0.1, 3.0, 0.1).name('Height').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'capsuleRadius', 0.1, 1.0, 0.05).name('Radius').onChange(() => updateUniforms());
    capsuleFolder.addColor(params, 'capsuleColor').name('Color').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'capsuleShininess', 8.0, 1024.0, 8.0).name('Shininess').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'capsuleDiffuse', 0.0, 1.0, 0.05).name('Diffuse').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'numCapsules', 1, 10, 1).name('Number of Capsules').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'capsuleSpacing', 1.0, 20.0, 0.5).name('Capsule Spacing').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'capsuleSpeedVariation', 0.0, 1.0, 0.05).name('Speed Variation').onChange(() => updateUniforms());
    capsuleFolder.add(params, 'capsuleColorVariation', 0.0, 1.0, 0.05).name('Color Variation').onChange(() => updateUniforms());

    const postProcessingFolder = gui.addFolder('Post-Processing');
    postProcessingFolder.add(params, 'chromaticAberrationStrength', 0.0, 0.1, 0.001).name('Chromatic Aberration').onChange(() => updateUniforms());

    function updateUniforms() {
        gl.uniform1f(uRadiusLocation, params.radius);
        gl.uniform1f(uNoiseAmpLocation, params.noiseAmplitude);
        gl.uniform1f(uSpeedLocation, params.speed);
        gl.uniform1f(uGlowIntensityLocation, params.glowIntensity);
        gl.uniform1f(uFogDensityLocation, params.fogDensity);
        gl.uniform1f(uLightIntensityLocation, params.lightIntensity);
        gl.uniform1f(uCausticStrengthLocation, params.causticStrength);
        gl.uniform1f(uBubbleDensityLocation, params.bubbleDensity);
        gl.uniform1f(uWaveSpeedLocation, params.waveSpeed);
        gl.uniform1f(uSpecularShininessLocation, params.specularShininess);
        let tunnelTypeValue;
        if (params.tunnelType === 'Underwater') {
            tunnelTypeValue = 0.0;
        } else if (params.tunnelType === 'Clouds') {
            tunnelTypeValue = 1.0;
        } else { // Lava
            tunnelTypeValue = 2.0;
        }
        gl.uniform1f(uTunnelTypeLocation, tunnelTypeValue);
        gl.uniform1f(uFocalLengthLocation, params.focalLength);
        gl.uniform1f(uBumpFactorLocation, params.bumpFactor);
        gl.uniform1f(uTunnelBendLocation, params.tunnelBend);
        gl.uniform1f(uCapsuleHeightLocation, params.capsuleHeight);
        gl.uniform1f(uCapsuleRadiusLocation, params.capsuleRadius);
        gl.uniform3f(uCapsuleColorLocation, params.capsuleColor[0] / 255.0, params.capsuleColor[1] / 255.0, params.capsuleColor[2] / 255.0);
        gl.uniform1f(uCapsuleShininessLocation, params.capsuleShininess);
        gl.uniform1f(uCapsuleDiffuseLocation, params.capsuleDiffuse);
        gl.uniform1f(uAnimateBendLocation, params.animateBend ? 1.0 : 0.0);
        gl.uniform1f(uBendAnimationSpeedLocation, params.bendAnimationSpeed);
        gl.uniform1f(uBendAnimationAmplitudeLocation, params.bendAnimationAmplitude);
        gl.uniform1f(uAnimateRadiusLocation, params.animateRadius ? 1.0 : 0.0);
        gl.uniform1f(uRadiusAnimationSpeedLocation, params.radiusAnimationSpeed);
        gl.uniform1f(uRadiusAnimationAmplitudeLocation, params.radiusAnimationAmplitude);
        gl.uniform1f(uChromaticAberrationStrengthLocation, params.chromaticAberrationStrength);
        gl.uniform1i(uNumCapsulesLocation, params.numCapsules);
        gl.uniform1f(uCapsuleSpacingLocation, params.capsuleSpacing);
        gl.uniform1f(uCapsuleSpeedVariationLocation, params.capsuleSpeedVariation);
        gl.uniform1f(uCapsuleColorVariationLocation, params.capsuleColorVariation);
    }

    // Resize canvas to match display size
    function resizeCanvas() {
        const displayWidth = window.innerWidth;
        const displayHeight = window.innerHeight;
        
        if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
            canvas.width = displayWidth;
            canvas.height = displayHeight;
            gl.viewport(0, 0, canvas.width, canvas.height);
        }
    }

    // Animation loop
    function render(time) {
        resizeCanvas();
        
        gl.clearColor(0, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT);
        
        gl.useProgram(program);
        
        // Set uniforms
        gl.uniform2f(iResolutionLocation, canvas.width, canvas.height);
        gl.uniform1f(iTimeLocation, time * 0.001);
        updateUniforms();
        
        gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
        gl.enableVertexAttribArray(positionLocation);
        gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);
        
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        
        requestAnimationFrame(render);
    }

    // Start animation
    resizeCanvas();
    updateUniforms();
    requestAnimationFrame(render);

    // Handle window resize
    window.addEventListener('resize', resizeCanvas);
}

main().catch(console.error);
