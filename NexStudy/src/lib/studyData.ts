export type SubjectCategory = 'Science' | 'Math' | 'Language' | 'Business' | 'Arts' | 'Other'
export type TaskType = 'Assignment' | 'Exam' | 'Revision' | 'Project'
export type Priority = 'High' | 'Medium' | 'Low'
export type ReminderChannel = 'App' | 'Email'
export type GoalStatus = 'On Track' | 'At Risk' | 'Done'
export type ThemeMode = 'light' | 'dark'

export interface Subject {
  id: string
  name: string
  category: SubjectCategory
  instructor: string
  weeklyGoal: number
  studiedHours: number
  progress: number
  examDate: string
  notes: string
}

export interface StudySession {
  id: string
  subject: string
  duration: number
  focusScore: number
  date: string
  notes: string
}

export interface PlannerTask {
  id: string
  title: string
  subject: string
  type: TaskType
  dueDate: string
  priority: Priority
  completed: boolean
  completedAt?: string
  notes: string
}

export interface NoteItem {
  id: string
  title: string
  subject: string
  updatedAt: string
  content: string
}

export interface GoalItem {
  id: string
  title: string
  targetHours: number
  progressHours: number
  deadline: string
  status: GoalStatus
}

export interface ReminderItem {
  id: string
  title: string
  remindAt: string
  channel: ReminderChannel
  completed: boolean
}

export interface FlashcardDeck {
  id: string
  title: string
  subject: string
  cardCount: number
  dueCount: number
  mastery: number
}

export interface TimetableClass {
  id: string
  title: string
  subject: string
  day: 'Saturday' | 'Sunday' | 'Monday' | 'Tuesday' | 'Wednesday' | 'Thursday' | 'Friday'
  time: string
  room: string
}

export interface UserSettings {
  fullName: string
  email: string
  dailyStudyGoal: number
  pomodoroMinutes: number
  shortBreakMinutes: number
  notificationsEnabled: boolean
  reminderChannel: ReminderChannel
  themeMode: ThemeMode
  focusModeEnabled: boolean
  dailyBriefingEnabled: boolean
}

export const STORAGE_KEYS = {
  subjects: 'nexstudy-subjects',
  sessions: 'nexstudy-sessions',
  planner: 'nexstudy-planner',
  notes: 'nexstudy-notes',
  goals: 'nexstudy-goals',
  reminders: 'nexstudy-reminders',
  flashcards: 'nexstudy-flashcards',
  timetable: 'nexstudy-timetable',
  settings: 'nexstudy-settings',
} as const

export type StudyStorageKey = (typeof STORAGE_KEYS)[keyof typeof STORAGE_KEYS]

export const STUDY_STORAGE_KEYS = Object.values(STORAGE_KEYS) as StudyStorageKey[]

const STUDY_DATA_SYNC_EVENT = 'nexstudy:data-sync'

export interface StudyWorkspaceData {
  subjects: Subject[]
  sessions: StudySession[]
  tasks: PlannerTask[]
  notes: NoteItem[]
  goals: GoalItem[]
  reminders: ReminderItem[]
  flashcards: FlashcardDeck[]
  timetable: TimetableClass[]
  settings: UserSettings
}

export interface StudyWorkspaceBackup {
  version: 1
  exportedAt: string
  data: StudyWorkspaceData
}

export const CATEGORY_OPTIONS = [
  { value: 'Science', label: 'Science' },
  { value: 'Math', label: 'Math' },
  { value: 'Language', label: 'Language' },
  { value: 'Business', label: 'Business' },
  { value: 'Arts', label: 'Arts' },
  { value: 'Other', label: 'Other' },
] as const

export const TASK_TYPE_OPTIONS = [
  { value: 'Assignment', label: 'Assignment' },
  { value: 'Exam', label: 'Exam' },
  { value: 'Revision', label: 'Revision' },
  { value: 'Project', label: 'Project' },
] as const

export const PRIORITY_OPTIONS = [
  { value: 'High', label: 'High' },
  { value: 'Medium', label: 'Medium' },
  { value: 'Low', label: 'Low' },
] as const

export const REMINDER_CHANNEL_OPTIONS = [
  { value: 'App', label: 'App' },
  { value: 'Email', label: 'Email' },
] as const

export const THEME_MODE_OPTIONS = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
] as const

export const WEEKDAY_OPTIONS = [
  { value: 'Saturday', label: 'Saturday' },
  { value: 'Sunday', label: 'Sunday' },
  { value: 'Monday', label: 'Monday' },
  { value: 'Tuesday', label: 'Tuesday' },
  { value: 'Wednesday', label: 'Wednesday' },
  { value: 'Thursday', label: 'Thursday' },
  { value: 'Friday', label: 'Friday' },
] as const

export const STARTER_SUBJECTS: Subject[] = [
  {
    id: 'sub-physics',
    name: 'Physics',
    category: 'Science',
    instructor: 'Dr. Rahman',
    weeklyGoal: 8,
    studiedHours: 5.5,
    progress: 72,
    examDate: '2026-05-24',
    notes: 'Focus on motion, force, and problem-solving drills.',
  },
  {
    id: 'sub-calculus',
    name: 'Calculus',
    category: 'Math',
    instructor: 'Prof. Karim',
    weeklyGoal: 6,
    studiedHours: 4,
    progress: 61,
    examDate: '2026-05-27',
    notes: 'Practice integration shortcuts and past questions.',
  },
  {
    id: 'sub-english',
    name: 'English Literature',
    category: 'Language',
    instructor: 'Ms. Farzana',
    weeklyGoal: 4,
    studiedHours: 3,
    progress: 84,
    examDate: '2026-06-02',
    notes: 'Revise themes, quotes, and comparison answers.',
  },
]

export const STARTER_SESSIONS: StudySession[] = [
  {
    id: 'session-1',
    subject: 'Physics',
    duration: 1.5,
    focusScore: 88,
    date: '2026-05-18',
    notes: 'Solved 3 force and motion problems.',
  },
  {
    id: 'session-2',
    subject: 'Calculus',
    duration: 1,
    focusScore: 76,
    date: '2026-05-17',
    notes: 'Revised substitution and definite integrals.',
  },
  {
    id: 'session-3',
    subject: 'English Literature',
    duration: 0.75,
    focusScore: 82,
    date: '2026-05-17',
    notes: 'Reviewed two poems and key quotations.',
  },
]

export const STARTER_TASKS: PlannerTask[] = [
  {
    id: 'task-1',
    title: 'Calculus Midterm Review',
    subject: 'Calculus',
    type: 'Exam',
    dueDate: '2026-05-19',
    priority: 'High',
    completed: false,
    completedAt: undefined,
    notes: 'Cover integration chapters 4-6.',
  },
  {
    id: 'task-2',
    title: 'Physics Assignment 4',
    subject: 'Physics',
    type: 'Assignment',
    dueDate: '2026-05-21',
    priority: 'Medium',
    completed: false,
    completedAt: undefined,
    notes: 'Submit derivations and worked examples.',
  },
  {
    id: 'task-3',
    title: 'Literature Theme Outline',
    subject: 'English Literature',
    type: 'Revision',
    dueDate: '2026-05-22',
    priority: 'Low',
    completed: true,
    completedAt: '2026-05-18',
    notes: 'Summarize themes for essay writing.',
  },
]

export const STARTER_NOTES: NoteItem[] = [
  {
    id: 'note-1',
    title: 'Force and Motion Summary',
    subject: 'Physics',
    updatedAt: '2026-05-18',
    content: 'Newton laws, free body diagrams, and momentum shortcuts.',
  },
  {
    id: 'note-2',
    title: 'Integration Rules',
    subject: 'Calculus',
    updatedAt: '2026-05-17',
    content: 'Substitution, integration by parts, and common definite integral patterns.',
  },
]

export const STARTER_GOALS: GoalItem[] = [
  {
    id: 'goal-1',
    title: 'Study 30 hours this month',
    targetHours: 30,
    progressHours: 12.5,
    deadline: '2026-05-31',
    status: 'On Track',
  },
  {
    id: 'goal-2',
    title: 'Reach 80% in Calculus',
    targetHours: 10,
    progressHours: 4,
    deadline: '2026-05-27',
    status: 'At Risk',
  },
]

export const STARTER_REMINDERS: ReminderItem[] = [
  {
    id: 'reminder-1',
    title: 'Submit Physics Assignment 4',
    remindAt: '2026-05-20T19:00',
    channel: 'App',
    completed: false,
  },
  {
    id: 'reminder-2',
    title: 'Review Calculus formulas',
    remindAt: '2026-05-19T08:00',
    channel: 'Email',
    completed: false,
  },
]

export const STARTER_FLASHCARDS: FlashcardDeck[] = [
  {
    id: 'deck-1',
    title: 'Physics Formula Drill',
    subject: 'Physics',
    cardCount: 28,
    dueCount: 9,
    mastery: 63,
  },
  {
    id: 'deck-2',
    title: 'Integration Identities',
    subject: 'Calculus',
    cardCount: 18,
    dueCount: 5,
    mastery: 71,
  },
]

export const STARTER_TIMETABLE: TimetableClass[] = [
  {
    id: 'class-1',
    title: 'Physics Lecture',
    subject: 'Physics',
    day: 'Sunday',
    time: '10:00 - 11:30',
    room: 'Room 204',
  },
  {
    id: 'class-2',
    title: 'Calculus Tutorial',
    subject: 'Calculus',
    day: 'Tuesday',
    time: '14:00 - 15:00',
    room: 'Lab 3',
  },
  {
    id: 'class-3',
    title: 'Literature Seminar',
    subject: 'English Literature',
    day: 'Thursday',
    time: '09:30 - 10:30',
    room: 'Hall B',
  },
]

export const DEFAULT_SETTINGS: UserSettings = {
  fullName: 'NexStudy Student',
  email: 'student@nexstudy.app',
  dailyStudyGoal: 4,
  pomodoroMinutes: 25,
  shortBreakMinutes: 5,
  notificationsEnabled: true,
  reminderChannel: 'App',
  themeMode: 'light',
  focusModeEnabled: false,
  dailyBriefingEnabled: true,
}

function canUseStorage() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined'
}

function emitStudyDataSync(keys: StudyStorageKey[]) {
  if (typeof window === 'undefined') {
    return
  }

  window.dispatchEvent(
    new CustomEvent<{ keys: StudyStorageKey[] }>(STUDY_DATA_SYNC_EVENT, {
      detail: { keys },
    }),
  )
}

function readStorage<T>(key: string, fallback: T): T {
  if (!canUseStorage()) {
    return fallback
  }

  const rawValue = window.localStorage.getItem(key)
  if (!rawValue) {
    return fallback
  }

  try {
    return JSON.parse(rawValue) as T
  } catch {
    window.localStorage.removeItem(key)
    return fallback
  }
}

function writeStorage<T>(key: string, value: T) {
  if (!canUseStorage()) {
    return
  }

  window.localStorage.setItem(key, JSON.stringify(value))
  emitStudyDataSync([key as StudyStorageKey])
}

function hasStoredValue(key: string) {
  return canUseStorage() && window.localStorage.getItem(key) !== null
}

function removeStorageValue(key: StudyStorageKey) {
  if (!canUseStorage()) {
    return
  }

  window.localStorage.removeItem(key)
  emitStudyDataSync([key])
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

export function formatIsoDate(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function getTodayIsoDate() {
  return formatIsoDate(new Date())
}

export function getOffsetIsoDate(offsetDays: number) {
  const date = new Date()
  date.setDate(date.getDate() + offsetDays)
  return formatIsoDate(date)
}

export function getGoalStatus(progressHours: number, targetHours: number): GoalStatus {
  if (progressHours >= targetHours) {
    return 'Done'
  }

  if (progressHours / targetHours >= 0.5) {
    return 'On Track'
  }

  return 'At Risk'
}

export function loadSubjects() {
  if (!hasStoredValue(STORAGE_KEYS.subjects)) {
    return STARTER_SUBJECTS
  }

  const subjects = readStorage(STORAGE_KEYS.subjects, STARTER_SUBJECTS)
  return Array.isArray(subjects) ? subjects : STARTER_SUBJECTS
}

export function saveSubjects(subjects: Subject[]) {
  writeStorage(STORAGE_KEYS.subjects, subjects)
}

export function loadSessions() {
  if (!hasStoredValue(STORAGE_KEYS.sessions)) {
    return STARTER_SESSIONS
  }

  const sessions = readStorage(STORAGE_KEYS.sessions, STARTER_SESSIONS)
  return Array.isArray(sessions) ? sessions : STARTER_SESSIONS
}

export function saveSessions(sessions: StudySession[]) {
  writeStorage(STORAGE_KEYS.sessions, sessions)
}

export function loadTasks() {
  if (!hasStoredValue(STORAGE_KEYS.planner)) {
    return STARTER_TASKS
  }

  const tasks = readStorage(STORAGE_KEYS.planner, STARTER_TASKS)
  if (!Array.isArray(tasks)) {
    return STARTER_TASKS
  }

  return tasks.map((task) => ({
    ...task,
    completedAt: task.completed ? task.completedAt ?? '' : undefined,
  }))
}

export function saveTasks(tasks: PlannerTask[]) {
  writeStorage(STORAGE_KEYS.planner, tasks)
}

export function loadNotes() {
  if (!hasStoredValue(STORAGE_KEYS.notes)) {
    return STARTER_NOTES
  }

  const notes = readStorage(STORAGE_KEYS.notes, STARTER_NOTES)
  return Array.isArray(notes) ? notes : STARTER_NOTES
}

export function saveNotes(notes: NoteItem[]) {
  writeStorage(STORAGE_KEYS.notes, notes)
}

export function loadGoals() {
  if (!hasStoredValue(STORAGE_KEYS.goals)) {
    return STARTER_GOALS
  }

  const goals = readStorage(STORAGE_KEYS.goals, STARTER_GOALS)
  if (!Array.isArray(goals)) {
    return STARTER_GOALS
  }

  return goals.map((goal) => ({
    ...goal,
    status: getGoalStatus(goal.progressHours, goal.targetHours),
  }))
}

export function saveGoals(goals: GoalItem[]) {
  writeStorage(
    STORAGE_KEYS.goals,
    goals.map((goal) => ({
      ...goal,
      status: getGoalStatus(goal.progressHours, goal.targetHours),
    })),
  )
}

export function loadReminders() {
  if (!hasStoredValue(STORAGE_KEYS.reminders)) {
    return STARTER_REMINDERS
  }

  const reminders = readStorage(STORAGE_KEYS.reminders, STARTER_REMINDERS)
  return Array.isArray(reminders) ? reminders : STARTER_REMINDERS
}

export function saveReminders(reminders: ReminderItem[]) {
  writeStorage(STORAGE_KEYS.reminders, reminders)
}

export function loadFlashcards() {
  if (!hasStoredValue(STORAGE_KEYS.flashcards)) {
    return STARTER_FLASHCARDS
  }

  const decks = readStorage(STORAGE_KEYS.flashcards, STARTER_FLASHCARDS)
  return Array.isArray(decks) ? decks : STARTER_FLASHCARDS
}

export function saveFlashcards(decks: FlashcardDeck[]) {
  writeStorage(STORAGE_KEYS.flashcards, decks)
}

export function loadTimetable() {
  if (!hasStoredValue(STORAGE_KEYS.timetable)) {
    return STARTER_TIMETABLE
  }

  const classes = readStorage(STORAGE_KEYS.timetable, STARTER_TIMETABLE)
  return Array.isArray(classes) ? classes : STARTER_TIMETABLE
}

export function saveTimetable(classes: TimetableClass[]) {
  writeStorage(STORAGE_KEYS.timetable, classes)
}

export function removeSubjectDependencies(subjectName: string) {
  saveSessions(loadSessions().filter((session) => session.subject !== subjectName))
  saveTasks(loadTasks().filter((task) => task.subject !== subjectName))
  saveNotes(loadNotes().filter((note) => note.subject !== subjectName))
  saveFlashcards(loadFlashcards().filter((deck) => deck.subject !== subjectName))
  saveTimetable(loadTimetable().filter((entry) => entry.subject !== subjectName))
}

export function loadSettings() {
  return {
    ...DEFAULT_SETTINGS,
    ...readStorage(STORAGE_KEYS.settings, DEFAULT_SETTINGS),
  }
}

export function saveSettings(settings: UserSettings) {
  writeStorage(STORAGE_KEYS.settings, { ...DEFAULT_SETTINGS, ...settings })
}

export function loadStudyWorkspace(): StudyWorkspaceData {
  return {
    subjects: loadSubjects(),
    sessions: loadSessions(),
    tasks: loadTasks(),
    notes: loadNotes(),
    goals: loadGoals(),
    reminders: loadReminders(),
    flashcards: loadFlashcards(),
    timetable: loadTimetable(),
    settings: loadSettings(),
  }
}

export function createStudyWorkspaceBackup(): StudyWorkspaceBackup {
  return {
    version: 1,
    exportedAt: new Date().toISOString(),
    data: loadStudyWorkspace(),
  }
}

export function saveStudyWorkspace(workspace: StudyWorkspaceData) {
  saveSubjects(workspace.subjects)
  saveSessions(workspace.sessions)
  saveTasks(workspace.tasks)
  saveNotes(workspace.notes)
  saveGoals(workspace.goals)
  saveReminders(workspace.reminders)
  saveFlashcards(workspace.flashcards)
  saveTimetable(workspace.timetable)
  saveSettings(workspace.settings)
}

export function resetStudyWorkspace() {
  saveStudyWorkspace({
    subjects: [],
    sessions: [],
    tasks: [],
    notes: [],
    goals: [],
    reminders: [],
    flashcards: [],
    timetable: [],
    settings: DEFAULT_SETTINGS,
  })
}

export function importStudyWorkspaceBackup(payload: unknown) {
  const backupRoot = isRecord(payload) ? payload : null
  const backupData = backupRoot && 'data' in backupRoot ? backupRoot.data : payload

  if (!isRecord(backupData)) {
    throw new Error('Backup file is not a valid NexStudy workspace export.')
  }

  const {
    subjects,
    sessions,
    tasks,
    notes,
    goals,
    reminders,
    flashcards,
    timetable,
    settings,
  } = backupData

  if (
    !Array.isArray(subjects) ||
    !Array.isArray(sessions) ||
    !Array.isArray(tasks) ||
    !Array.isArray(notes) ||
    !Array.isArray(goals) ||
    !Array.isArray(reminders) ||
    !Array.isArray(flashcards) ||
    !Array.isArray(timetable) ||
    !isRecord(settings)
  ) {
    throw new Error('Backup file is missing one or more study collections.')
  }

  saveStudyWorkspace({
    subjects: subjects as Subject[],
    sessions: sessions as StudySession[],
    tasks: tasks as PlannerTask[],
    notes: notes as NoteItem[],
    goals: goals as GoalItem[],
    reminders: reminders as ReminderItem[],
    flashcards: flashcards as FlashcardDeck[],
    timetable: timetable as TimetableClass[],
    settings: { ...DEFAULT_SETTINGS, ...(settings as Partial<UserSettings>) },
  })
}

export function subscribeToStudyData(listener: () => void, keys: StudyStorageKey[] = STUDY_STORAGE_KEYS) {
  if (typeof window === 'undefined') {
    return () => {}
  }

  const watchedKeys = new Set(keys)

  function handleStorage(event: StorageEvent) {
    if (!event.key || watchedKeys.has(event.key as StudyStorageKey)) {
      listener()
    }
  }

  function handleSync(event: Event) {
    const detail = (event as CustomEvent<{ keys?: StudyStorageKey[] }>).detail

    if (!detail?.keys || detail.keys.some((key) => watchedKeys.has(key))) {
      listener()
    }
  }

  window.addEventListener('storage', handleStorage)
  window.addEventListener(STUDY_DATA_SYNC_EVENT, handleSync)

  return () => {
    window.removeEventListener('storage', handleStorage)
    window.removeEventListener(STUDY_DATA_SYNC_EVENT, handleSync)
  }
}

export function clearStoredStudyWorkspace() {
  for (const key of STUDY_STORAGE_KEYS) {
    removeStorageValue(key)
  }
}
