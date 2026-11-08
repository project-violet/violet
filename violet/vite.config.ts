import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const appRoot = fileURLToPath(new URL('.', import.meta.url));
const frontend = path.resolve(appRoot, '../violet-web/packages/frontend');
const host = process.env.TAURI_DEV_HOST;

export default defineConfig({
  root: frontend,
  // The HTML, assets, styles and components all belong to violet-web.
  plugins: [react(), {
    name: 'violet-native-entry',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        if (!html.includes('src="/src/main.tsx"')) throw new Error('Shared frontend entry changed; update the native entry transform.');
        return html.replace('src="/src/main.tsx"', `src="/@fs/${appRoot}src/main.tsx"`);
      },
    },
  }],
  resolve: {
    alias: {
      '@': path.join(frontend, 'src'),
      '@violet-web/shared': path.resolve(appRoot, '../violet-web/packages/shared/src/index.ts'),
      // Share one React runtime with the sibling frontend.
      'react': path.join(appRoot, 'node_modules/react'),
      'react-dom': path.join(appRoot, 'node_modules/react-dom'),
      'axios': path.join(appRoot, 'node_modules/axios'),
    },
    dedupe: ['react', 'react-dom'],
  },
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    host: host || '127.0.0.1',
    hmr: host ? { protocol: 'ws', host, port: 1421 } : undefined,
    fs: { allow: [path.resolve(appRoot, '..')] },
    watch: { ignored: ['**/src-tauri/**'] },
  },
  build: {
    outDir: path.join(appRoot, 'dist'),
    emptyOutDir: true,
    target: ['safari15', 'chrome105'],
  },
});
