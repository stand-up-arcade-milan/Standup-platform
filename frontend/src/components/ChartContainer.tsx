import { Bar, Line, Pie, Doughnut } from 'react-chartjs-2'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  PointElement,
  LineElement,
  ArcElement
} from 'chart.js'
import type { ChartData } from '../types/dashboard'

// Registra i componenti di ChartJS
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  PointElement,
  LineElement,
  ArcElement
)

type ChartContainerProps = {
  type: 'bar' | 'line' | 'pie' | 'doughnut'
  data: ChartData
  title: string
  height?: number
}

const colors = {
  lime: '#cbff8c',
  brick: '#c03221',
  jungle: '#3f826d',
  coffee: '#171219',
  ghost: '#f7f7ff',
}

export function ChartContainer({ type, data, title, height = 300 }: ChartContainerProps) {
  const ChartComponent = {
    bar: Bar,
    line: Line,
    pie: Pie,
    doughnut: Doughnut,
  }[type]

  // Applica i colori ARCADE ai dati
  const styledData = {
    ...data,
    datasets: data.datasets.map(dataset => ({
      ...dataset,
      backgroundColor: dataset.backgroundColor || colors.lime,
      borderColor: dataset.borderColor || colors.lime,
    })),
  }

  return (
    <div className="chart-container">
      <h3>{title}</h3>
      <div className="chart-wrapper" style={{ height: `${height}px` }}>
        {ChartComponent && (
          <ChartComponent
            data={styledData}
            options={{
              responsive: true,
              maintainAspectRatio: false,
              plugins: {
                legend: {
                  position: 'top' as const,
                  labels: { color: colors.ghost },
                },
                title: { display: false },
              },
              scales: type !== 'pie' && type !== 'doughnut' ? {
                x: {
                  ticks: { color: colors.ghost },
                  grid: { color: 'rgba(255, 255, 255, 0.1)' },
                },
                y: {
                  ticks: { color: colors.ghost },
                  grid: { color: 'rgba(255, 255, 255, 0.1)' },
                },
              } : {},
            }}
          />
        )}
      </div>
    </div>
  )
}
