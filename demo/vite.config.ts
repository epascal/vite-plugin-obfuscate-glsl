import { defineConfig } from 'vite'
import reactRefresh from '@vitejs/plugin-react-refresh'
import obfuscateGlsl from 'vite-plugin-obfuscate-glsl'

export default defineConfig({
  plugins: [
    reactRefresh(),
    obfuscateGlsl(),
  ],
})
