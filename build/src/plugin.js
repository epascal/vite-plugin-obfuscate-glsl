"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
exports.default = (config = {}) => {
    return {
        name: 'obfuscate-glsl',
        transform(src, id) {
            console.log(id);
            const cmd = (0, child_process_1.spawnSync)('shader_minifier.exe');
            if (cmd.status === 0) {
                return src;
            }
            else {
                return 'Error';
            }
        },
    };
};
//# sourceMappingURL=plugin.js.map