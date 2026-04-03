import { useWizardNavigate } from '../../lib/use-wizard'

const URL_RE = /(https?:\/\/[^\s)]+)/g
const STEP_RE = /@step:([a-zA-Z0-9-]+)\[([^\]]+)\]/g

export function HelpText({ text, className = 'text-xs text-gray-500' }: { text: string; className?: string }) {
  const navigateTo = useWizardNavigate()
  // Split on both external URLs and @step: references
  const combined = new RegExp(`${URL_RE.source}|${STEP_RE.source}`, 'g')
  const parts: React.ReactNode[] = []
  let lastIndex = 0
  let match: RegExpExecArray | null

  while ((match = combined.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push(<span key={lastIndex}>{text.slice(lastIndex, match.index)}</span>)
    }
    if (match[1]) {
      // External URL
      const url = match[1]
      parts.push(
        <a key={match.index} href={url} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">
          {simplifyUrl(url)}
        </a>
      )
    } else if (match[2] && match[3]) {
      // Step reference: @step:step-id[Label]
      const stepId = match[2]
      const label = match[3]
      parts.push(
        <button
          key={match.index}
          type="button"
          onClick={() => navigateTo?.(stepId)}
          className="text-blue-600 hover:underline cursor-pointer"
        >
          {label}
        </button>
      )
    }
    lastIndex = match.index + match[0].length
  }
  if (lastIndex < text.length) {
    parts.push(<span key={lastIndex}>{text.slice(lastIndex)}</span>)
  }

  return <p className={className}>{parts}</p>
}

function simplifyUrl(url: string): string {
  try {
    const u = new URL(url)
    const host = u.hostname.replace(/^www\./, '')
    // Show just the domain + last meaningful path segment
    const segments = u.pathname.split('/').filter(Boolean)
    if (segments.length === 0) return host
    const last = segments[segments.length - 1].replace(/#.*$/, '')
    return `${host}/.../${last}`
  } catch {
    return url
  }
}
