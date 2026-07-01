import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { loadSubjects, STORAGE_KEYS } from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function SubjectProgressChart() {
  const data = useStudyLiveValue(
    () =>
      loadSubjects().map((subject) => ({
        name: subject.name,
        progress: subject.progress,
      })),
    [STORAGE_KEYS.subjects],
  )

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(110, 86, 52, 0.12)" />
          <XAxis dataKey="name" stroke="var(--color-text-muted)" />
          <YAxis stroke="var(--color-text-muted)" />
          <Tooltip
            cursor={{ fill: 'rgba(46, 140, 129, 0.06)' }}
            contentStyle={{
              backgroundColor: 'var(--surface-tooltip)',
              border: '1px solid rgba(110, 86, 52, 0.16)',
              borderRadius: '16px',
            }}
          />
          <Bar dataKey="progress" fill="var(--color-accent-teal)" radius={[8, 8, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
