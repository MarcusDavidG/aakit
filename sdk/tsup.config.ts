import { defineConfig } from 'tsup'

export default defineConfig({
  entry: {
    index: 'src/index.ts',
    'core/index': 'src/core/index.ts',
    'passkey/index': 'src/passkey/index.ts',
    'wallet/index': 'src/wallet/index.ts',
  },
  format: ['cjs', 'esm'],
  dts: false, // Disabled for now
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
  external: ['viem'],
})
