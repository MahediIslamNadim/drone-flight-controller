import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { getOffsetIsoDate, loadSessions, STORAGE_KEYS } from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function DailyStudyChart() {
  const data = useStudyLiveValue(
    () => {
      const sessions = loadSessions()

      return [...Array.from({ length: 7 }, (_, index) => {
        const date = new Date()
        date.setDate(date.getDate() - (6 - index))
        const key = getOffsetIsoDate(index - 6)
        const total = sessions
          .filter((session) => session.date === key)
          .reduce((sum, session) => sum + session.duration, 0)

        return {
          day: date.toLocaleDateString('en-US', { weekday: 'short' }),
          hours: Number(total.toFixed(1)),
        }
      })]
    },
    [STORAGE_KEYS.sessions],
  )

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(0, 212, 255, 0.12)" />
          <XAxis dataKey="day" stroke="var(--color-text-muted)" />
          <YAxis stroke="var(--color-text-muted)" />
          <Tooltip
            cursor={{ fill: 'rgba(0, 212, 255, 0.06)' }}
            contentStyle={{
              backgroundColor: 'var(--surface-tooltip)',
              border: '1px solid rgba(0, 212, 255, 0.16)',
              borderRadius: '16px',
            }}
          />
          <Bar dataKey="hours" fill="var(--color-primary)" radius={[8, 8, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
