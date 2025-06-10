# vite-plugin-obfuscate-glsl

[![npm](https://img.shields.io/npm/v/vite-plugin-obfuscate-glsl.svg)](https://www.npmjs.com/package/vite-plugin-obfuscate-glsl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code style: Prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg)](https://github.com/prettier/prettier)

> Plugin Vite pour obfusquer les shaders GLSL en utilisant [Shader_Minifier](https://github.com/laurentlb/Shader_Minifier)

## Installation

```bash
npm install vite-plugin-obfuscate-glsl --save-dev
# ou
yarn add vite-plugin-obfuscate-glsl -D
# ou
pnpm add vite-plugin-obfuscate-glsl -D
```

## Fonctionnalités

- Obfuscation des fichiers GLSL dans votre projet Vite
- Utilise l'outil Shader_Minifier pour une minification optimale
- Préserve les variables externes
- Fonctionne uniquement en mode production (pas en mode développement/watch)

## Usage

Dans votre fichier de configuration Vite (`vite.config.js` ou `vite.config.ts`) :

```js
import { defineConfig } from 'vite'
import obfuscateGlsl from 'vite-plugin-obfuscate-glsl'

export default defineConfig({
  plugins: [
    obfuscateGlsl({
      shaderMinifier: './node_modules/vite-plugin-obfuscate-glsl/shader_minifier.exe'
    })
  ]
})
```

## Configuration

| Option | Type | Description |
|--------|------|-------------|
| `shaderMinifier` | `string` | Chemin vers l'exécutable shader_minifier (inclus dans le package) |

## Comment ça marche

Le plugin intercepte les fichiers `.glsl?raw` pendant le processus de build et les traite avec Shader_Minifier pour produire une version obfusquée et minifiée. Cette transformation n'est appliquée qu'en mode production.

## Exemple

Importez vos shaders GLSL dans votre code :

```js
import fragmentShader from './shaders/fragment.glsl?raw'
import vertexShader from './shaders/vertex.glsl?raw'
```

Lors de la construction en production, ces shaders seront automatiquement obfusqués.

## Licence

MIT © Eric Pascal
