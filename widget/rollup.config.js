import { nodeResolve} from '@rollup/plugin-node-resolve'
import typescript from '@rollup/plugin-typescript';
import commonjs from '@rollup/plugin-commonjs';
import replace from '@rollup/plugin-replace';
export default {
    input: [
        'src/staticHtml.tsx',
        "src/mathjax.tsx",
        "src/rubiks.tsx",
        "src/mermaid.tsx",
        "src/squares.tsx"
    ],
    output : {
        dir : "dist",
        format : "es"
    },
    external: [
        'react',
        'react-dom',
        '@lean4/infoview',
    ],
    plugins: [
        typescript({
            tsconfig: "./tsconfig.json",
            outputToFilesystem: false,
            sourceMap: false
        }),
        nodeResolve({
            browser: true
        }),
        replace({
            'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
            preventAssignment: true // TODO delete when `true` becomes the default
        }),
        commonjs(),
    ]
}
