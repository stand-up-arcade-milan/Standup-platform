import { useState } from 'react'

type DateRangePickerProps = {
  from: string
  to: string
  onChange: (from: string, to: string) => void
}

export function DateRangePicker({ from, to, onChange }: DateRangePickerProps) {
  const [localFrom, setLocalFrom] = useState(from)
  const [localTo, setLocalTo] = useState(to)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onChange(localFrom, localTo)
  }

  return (
    <form onSubmit={handleSubmit} className="date-range-form">
      <div className="date-range-inputs">
        <div className="form-group">
          <label htmlFor="from">Dal</label>
          <input
            type="date"
            id="from"
            value={localFrom}
            onChange={(e) => setLocalFrom(e.target.value)}
            className="form-input"
          />
        </div>
        <div className="form-group">
          <label htmlFor="to">Al</label>
          <input
            type="date"
            id="to"
            value={localTo}
            onChange={(e) => setLocalTo(e.target.value)}
            className="form-input"
          />
        </div>
        <button type="submit" className="button" style={{ marginTop: '0.5rem', alignSelf: 'flex-end' }}>
          Applica
        </button>
      </div>
    </form>
  )
}
