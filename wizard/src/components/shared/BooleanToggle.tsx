import { HelpText } from './HelpText'

interface BooleanToggleProps {
  label: string
  value: boolean
  onChange: (value: boolean) => void
  helpText?: string
}

export function BooleanToggle({ label, value, onChange, helpText }: BooleanToggleProps) {
  const id = label.replace(/\s+/g, '-').toLowerCase()
  return (
    <div className="flex items-center justify-between">
      <div>
        <span id={id} className="text-sm font-medium text-gray-700">{label}</span>
        {helpText && <HelpText text={helpText} />}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={value}
        aria-labelledby={id}
        onClick={() => onChange(!value)}
        className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors ${
          value ? 'bg-blue-600' : 'bg-gray-200'
        }`}
      >
        <span
          className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition-transform ${
            value ? 'translate-x-5' : 'translate-x-0'
          }`}
        />
      </button>
    </div>
  )
}
