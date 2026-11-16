import { EdizioneSelector } from './EdizioneSelector'
import { DateRangePicker } from './DateRangePicker'

type FilterBarProps = {
  edizioni: number[]
  selectedEdizione: number
  from: string
  to: string
  onEdizioneChange: (anno: number) => void
  onDateRangeChange: (from: string, to: string) => void
}

export function FilterBar({
  edizioni,
  selectedEdizione,
  from,
  to,
  onEdizioneChange,
  onDateRangeChange,
}: FilterBarProps) {
  return (
    <div className="filter-bar">
      <EdizioneSelector
        edizioni={edizioni}
        selected={selectedEdizione}
        onChange={onEdizioneChange}
      />
      <DateRangePicker
        from={from}
        to={to}
        onChange={onDateRangeChange}
      />
    </div>
  )
}
