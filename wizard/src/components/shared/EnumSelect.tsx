import { ChevronDown } from 'lucide-react'
import { HelpText } from './HelpText'

interface EnumSelectProps {
  label: string
  value: string
  onChange: (value: string) => void
  options: string[]
  required?: boolean
  helpText?: string
  placeholder?: string
}

export function EnumSelect({ label, value, onChange, options, required, helpText, placeholder }: EnumSelectProps) {
  const id = label.replace(/\s+/g, '-').toLowerCase()
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      <div className="relative">
        <select
          id={id}
          value={value ?? ''}
          onChange={e => onChange(e.target.value)}
          required={required}
          className="block w-full appearance-none rounded-md border border-gray-300 bg-white px-3 py-2 pr-9 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 cursor-pointer"
        >
          {placeholder && <option value="">{placeholder}</option>}
          {options.map(opt => (
            <option key={opt} value={opt}>{opt}</option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
      </div>
      {helpText && <HelpText text={helpText} />}
    </div>
  )
}
