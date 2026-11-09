type EdizioneSelectorProps = {
  edizioni: number[]
  selected: number
  onChange: (anno: number) => void
}

export function EdizioneSelector({ edizioni, selected, onChange }: EdizioneSelectorProps) {
  return (
    <div className="form-group">
      <label htmlFor="edizione">Edizione</label>
      <select
        id="edizione"
        value={selected}
        onChange={(e) => onChange(Number(e.target.value))}
        className="form-select"
      >
        {edizioni.map((anno) => (
          <option key={anno} value={anno}>
            ARCADE {anno}
          </option>
        ))}
      </select>
    </div>
  )
}
