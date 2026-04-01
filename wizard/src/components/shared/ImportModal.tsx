import { useState, useRef, useEffect, useCallback } from 'react'
import { X, Upload } from 'lucide-react'

interface ImportModalProps {
  onImport: (yaml: string) => void
  onClose: () => void
}

export function ImportModal({ onImport, onClose }: ImportModalProps) {
  const [text, setText] = useState('')
  const [error, setError] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const dialogRef = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    const dialog = dialogRef.current
    if (dialog && !dialog.open) {
      dialog.showModal()
    }
  }, [])

  const handleClose = useCallback(() => {
    dialogRef.current?.close()
    onClose()
  }, [onClose])

  const handleImport = () => {
    if (!text.trim()) {
      setError('Please paste or upload YAML content')
      return
    }
    setError(null)
    onImport(text)
  }

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      setText(reader.result as string)
      setError(null)
    }
    reader.readAsText(file)
  }

  return (
    <dialog
      ref={dialogRef}
      onClose={handleClose}
      className="fixed inset-0 z-50 bg-transparent p-0 backdrop:bg-black/50"
    >
      <div className="flex min-h-screen items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-2xl">
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900">Import values.yaml</h3>
            <button type="button" aria-label="Close dialog" onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <X className="h-5 w-5" />
            </button>
          </div>
          <div className="px-6 py-4 space-y-4">
            <p className="text-sm text-gray-600">Paste your existing values.yaml content or upload a file.</p>
            <textarea
              value={text}
              onChange={e => { setText(e.target.value); setError(null) }}
              rows={12}
              placeholder="Paste YAML here..."
              spellCheck={false}
              autoFocus
              className="block w-full rounded-md border border-gray-300 bg-white px-3 py-2 font-mono text-xs shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            {error && <p className="text-sm text-red-600">{error}</p>}
            <div className="flex items-center gap-3">
              <input ref={fileRef} type="file" accept=".yaml,.yml" onChange={handleFile} className="hidden" />
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="inline-flex items-center gap-1.5 rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50"
              >
                <Upload className="h-4 w-4" /> Upload File
              </button>
            </div>
          </div>
          <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-200">
            <button type="button" onClick={handleClose} className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">
              Cancel
            </button>
            <button type="button" onClick={handleImport} className="rounded-md bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">
              Import
            </button>
          </div>
        </div>
      </div>
    </dialog>
  )
}
