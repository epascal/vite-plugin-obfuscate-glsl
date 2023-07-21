import { Plugin, transformWithEsbuild } from 'vite'
import { spawnSync } from 'child_process'

type PluginConfig = {
  shaderMinifier?: string
}

export default (config: PluginConfig = {}): Plugin => {
  return {
    name: 'obfuscate-glsl',
    transform(src, id) {
      if (id.indexOf('glsl') >= 0 ) console.log(`glsl processing ${id}`);
      if (!this.meta.watchMode && config.shaderMinifier && id.endsWith('.glsl?raw')) {
        // console.log('Processing '+id);
        const glslCode = JSON.parse(src.replace('export default', ''));
        // console.log(id, config.shaderMinifier)
        const cmd = spawnSync(config.shaderMinifier, [ '--format', 'text', '--preserve-externals', '-o', '-', id.replace('?raw', '') ]);
        if (cmd.status === 0) {
          // console.log('\nResult GLSL ', cmd.stdout.toString());
          return `export default ${JSON.stringify(cmd.stdout.toString())}`;
        } else {
          console.log(`Error in GLSL conversion ${id}\n`);
          return `Error in GLSL conversion ${id}`;
        }
      }
    },
  }
}
