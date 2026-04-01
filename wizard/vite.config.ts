import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'
import fs from 'fs'

let base = process.env.VITE_BASE || '/chartpack/wizard/'
if (!base.endsWith('/')) base += '/'

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    {
      name: 'serve-root-schema',
      configureServer(server) {
        server.middlewares.use(`${base}values.schema.json`, (_req, res) => {
          const file = path.resolve(__dirname, '../values.schema.json')
          res.setHeader('Content-Type', 'application/json')
          fs.createReadStream(file)
            .on('error', () => {
              res.statusCode = 500
              res.end(JSON.stringify({ error: 'Failed to read values.schema.json' }))
            })
            .pipe(res)
        })
      },
    },
  ],
  base,
  build: {
    rollupOptions: {
      plugins: [
        {
          name: 'copy-root-schema',
          generateBundle() {
            this.emitFile({
              type: 'asset',
              fileName: 'values.schema.json',
              source: fs.readFileSync(path.resolve(__dirname, '../values.schema.json'), 'utf-8'),
            })
          },
        },
      ],
    },
  },
})
