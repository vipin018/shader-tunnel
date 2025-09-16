import { GUI } from 'lil-gui';

async function loadShaderFile(url) {
    const response = await fetch(url);
    return await response.text();
}

async function main() {
    const canvas = document.getElementById('canvas');
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    
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
    const uWaterColorLocation = gl.getUniformLocation(program, 'uWaterColor');
    const uFogDensityLocation = gl.getUniformLocation(program, 'uFogDensity');
    const uLightIntensityLocation = gl.getUniformLocation(program, 'uLightIntensity');
    const uCausticStrengthLocation = gl.getUniformLocation(program, 'uCausticStrength');
    const uBubbleDensityLocation = gl.getUniformLocation(program, 'uBubbleDensity');

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
        waterColor: [0, 128, 255], // RGB values (0-255) for blue water vec3(0.0, 0.5, 1.0)
        fogDensity: 0.05,
        lightIntensity: 1.0,
        causticStrength: 1.0,
        bubbleDensity: 1.0
    };

    const gui = new GUI();
    gui.add(params, 'radius', 0.5, 3.0, 0.1).name('Tunnel Radius').onChange(() => updateUniforms());
    gui.add(params, 'noiseAmplitude', 0.0, 1.0, 0.01).name('Noise Amplitude').onChange(() => updateUniforms());
    gui.add(params, 'speed', 0.1, 2.0, 0.1).name('Camera Speed').onChange(() => updateUniforms());
    gui.add(params, 'glowIntensity', 0.0, 2.0, 0.1).name('Glow Intensity').onChange(() => updateUniforms());
    gui.addColor(params, 'waterColor').name('Water Color').onChange((value) => {
        console.log('Water color changed to:', value);
        updateUniforms();
    });
    gui.add(params, 'fogDensity', 0.01, 0.2, 0.01).name('Fog Density').onChange(() => updateUniforms());
    gui.add(params, 'lightIntensity', 0.5, 2.0, 0.1).name('Light Intensity').onChange(() => updateUniforms());
    gui.add(params, 'causticStrength', 0.0, 2.0, 0.1).name('Caustic Strength').onChange(() => updateUniforms());
    gui.add(params, 'bubbleDensity', 0.0, 2.0, 0.1).name('Bubble Density').onChange(() => updateUniforms());

    function updateUniforms() {
        gl.uniform1f(uRadiusLocation, params.radius);
        gl.uniform1f(uNoiseAmpLocation, params.noiseAmplitude);
        gl.uniform1f(uSpeedLocation, params.speed);
        gl.uniform1f(uGlowIntensityLocation, params.glowIntensity);
        gl.uniform3f(uWaterColorLocation, 
            params.waterColor[0] / 255.0, 
            params.waterColor[1] / 255.0, 
            params.waterColor[2] / 255.0
        );
        gl.uniform1f(uFogDensityLocation, params.fogDensity);
        gl.uniform1f(uLightIntensityLocation, params.lightIntensity);
        gl.uniform1f(uCausticStrengthLocation, params.causticStrength);
        gl.uniform1f(uBubbleDensityLocation, params.bubbleDensity);
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