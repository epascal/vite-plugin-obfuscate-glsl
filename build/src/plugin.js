"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
exports.default = (config = {}) => {
    return {
        name: 'obfuscate-glsl',
        transform(src, id) {
            if (!this.meta.watchMode && config.shaderMinifier && id.endsWith('.glsl?raw')) {
                const glslCode = JSON.parse(src.replace('export default', ''));
                const cmd = (0, child_process_1.spawnSync)(config.shaderMinifier, ['--format', 'text', '--preserve-externals', '-o', '-', id.replace('?raw', '')]);
                if (cmd.status === 0) {
                    return `export default ${JSON.stringify(cmd.stdout.toString())}`;
                }
                else {
                    console.log('Error');
                    return 'Error';
                }
            }
        },
    };
};
//# sourceMappingURL=plugin.js.map