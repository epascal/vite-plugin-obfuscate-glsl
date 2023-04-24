import { Plugin, transformWithEsbuild } from 'vite'
import { spawnSync } from 'child_process';

type PluginConfig = {}

export default (config: PluginConfig = {}): Plugin => {
  return {
    name: 'obfuscate-glsl',
    transform(src, id) {
      console.log(id);
      const cmd = spawnSync('shader_minifier.exe');
      if (cmd.status === 0) {
        return src;
      } else {
        return 'Error';
      }
    },
  }
}
