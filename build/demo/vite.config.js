import { defineConfig } from 'vite';
import reactRefresh from '@vitejs/plugin-react-refresh';
import obfuscateGlsl from 'vite-plugin-obfuscate-glsl';
export default defineConfig({
    plugins: [
        reactRefresh(),
        obfuscateGlsl({
            'shaderMinifier': '/home/epascal/Projects/vite-plugin-obfuscate-glsl/shader_minifier.exe'
        }),
    ],
});
//# sourceMappingURL=vite.config.js.map