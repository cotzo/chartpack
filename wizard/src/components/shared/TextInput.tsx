import { HelpText } from './HelpText'

interface TextInputProps {
  label: string
  value: string
  onChange: (value: string) => void
  placeholder?: string
  required?: boolean
  helpText?: string
  error?: string
  type?: 'text' | 'number'
  min?: number
  max?: number
}

export function TextInput({ label, value, onChange, placeholder, required, helpText, error, type = 'text', min, max }: TextInputProps) {
  const id = label.replace(/\s+/g, '-').toLowerCase()
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      <input
        id={id}
        type={type}
        value={value ?? ''}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        required={required}
        min={min}
        max={max}
        className={`block w-full rounded-md border bg-white px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 ${
          error ? 'border-red-300 focus:ring-red-500' : 'border-gray-300'
        }`}
      />
      {helpText && !error && <HelpText text={helpText} />}
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  )
}
