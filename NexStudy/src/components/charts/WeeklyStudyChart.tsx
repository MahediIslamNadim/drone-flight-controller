import { Line, LineChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { getOffsetIsoDate, loadSessions, STORAGE_KEYS } from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function WeeklyStudyChart() {
  const data = useStudyLiveValue(
    () => {
      const recentDates = new Set(Array.from({ length: 7 }, (_, index) => getOffsetIsoDate(index - 6)))
      const sessions = loadSessions().filter((session) => recentDates.has(session.date))
      const weeklyMap = new Map<string, number>()

      for (const session of sessions) {
        weeklyMap.set(session.subject, (weeklyMap.get(session.subject) ?? 0) + session.duration)
      }

      return [...weeklyMap.entries()]
        .map(([subject, hours]) => ({
          subject,
          hours: Number(hours.toFixed(1)),
        }))
        .sort((a, b) => b.hours - a.hours)
    },
    [STORAGE_KEYS.sessions],
  )

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(110, 86, 52, 0.12)" />
          <XAxis dataKey="subject" stroke="var(--color-text-muted)" />
          <YAxis stroke="var(--color-text-muted)" />
          <Tooltip
            cursor={{ stroke: 'rgba(186, 133, 47, 0.3)' }}
            contentStyle={{
              backgroundColor: 'var(--surface-tooltip)',
              border: '1px solid rgba(110, 86, 52, 0.16)',
              borderRadius: '16px',
            }}
          />
          <Line
            type="monotone"
            dataKey="hours"
            stroke="var(--color-accent-amber)"
            strokeWidth={3}
            dot={{ fill: 'var(--color-accent-amber)' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
