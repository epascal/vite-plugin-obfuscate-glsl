import { spawnSync } from 'child_process';
export default (config = {}) => {
    return {
        name: 'obfuscate-glsl',
        transform(src, id) {
            if (id.indexOf('glsl') >= 0)
                console.log(`glsl processing ${id}`);
            if (!this.meta.watchMode && config.shaderMinifier && id.endsWith('.glsl?raw')) {
                const glslCode = JSON.parse(src.replace('export default', ''));
                const cmd = spawnSync(config.shaderMinifier, ['--format', 'text', '--preserve-externals', '-o', '-', id.replace('?raw', '')]);
                if (cmd.status === 0) {
                    return `export default ${JSON.stringify(cmd.stdout.toString())}`;
                }
                else {
                    console.log(`Error in GLSL conversion ${id}\n`);
                    return `Error in GLSL conversion ${id}`;
                }
            }
        },
    };
};
//# sourceMappingURL=plugin.js.map