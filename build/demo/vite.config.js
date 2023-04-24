"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const vite_1 = require("vite");
const plugin_react_refresh_1 = __importDefault(require("@vitejs/plugin-react-refresh"));
const vite_plugin_obfuscate_glsl_1 = __importDefault(require("vite-plugin-obfuscate-glsl"));
exports.default = (0, vite_1.defineConfig)({
    plugins: [
        (0, plugin_react_refresh_1.default)(),
        (0, vite_plugin_obfuscate_glsl_1.default)(),
    ],
});
//# sourceMappingURL=vite.config.js.map