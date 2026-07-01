import { useEffect, useState } from 'react'
import { Plus } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import Textarea from '../../components/ui/Textarea'
import Modal from '../../components/ui/Modal'
import { getTodayIsoDate, type NoteItem, loadNotes, loadSubjects, saveNotes } from '../../lib/studyData'

interface NoteFormState {
  title: string
  subject: string
}

function createFormState() {
  return {
    title: '',
    subject: loadSubjects()[0]?.name ?? '',
  }
}

export default function NotesPage() {
  const [notes, setNotes] = useState<NoteItem[]>(loadNotes)
  const [activeNoteId, setActiveNoteId] = useState<string>(loadNotes()[0]?.id ?? '')
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<NoteFormState>(createFormState)
  const [error, setError] = useState('')
  const subjects = loadSubjects()
  const hasSubjects = subjects.length > 0
  const activeNote = notes.find((note) => note.id === activeNoteId) ?? notes[0]

  useEffect(() => {
    saveNotes(notes)
  }, [notes])

  function closeModal() {
    setIsModalOpen(false)
    setForm(createFormState())
    setError('')
  }

  function addNote() {
    if (!form.title.trim()) {
      setError('Note title is required.')
      return
    }

    if (!form.subject) {
      setError('Add a subject first before creating notes.')
      return
    }

    const nextNote: NoteItem = {
      id: `note-${Date.now()}`,
      title: form.title.trim(),
      subject: form.subject,
      updatedAt: getTodayIsoDate(),
      content: '',
    }

    setNotes((current) => [nextNote, ...current])
    setActiveNoteId(nextNote.id)
    closeModal()
  }

  function updateActiveNote(content: string) {
    if (!activeNote) return

    setNotes((current) =>
      current.map((note) =>
        note.id === activeNote.id
          ? { ...note, content, updatedAt: getTodayIsoDate() }
          : note,
      ),
    )
  }

  const subjectOptions = subjects.map((subject) => ({
    value: subject.name,
    label: subject.name,
  }))

  return (
    <div className="space-y-6">
      <PageHeader
        title="Notes"
        subtitle="Keep lecture notes, revision summaries, and quick references in one place."
        actions={
          <Button icon={<Plus size={18} />} type="button" onClick={() => setIsModalOpen(true)} disabled={!hasSubjects}>
            New Note
          </Button>
        }
      />
      {!hasSubjects && (
        <Card glass className="text-sm text-[var(--color-text-muted)]">
          Add a subject first from the Subjects page to create notes linked to your study plan.
        </Card>
      )}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="md:col-span-1 space-y-4">
          <Card glass className="space-y-3">
            <h3 className="text-lg font-semibold text-[var(--color-text)]">Note List</h3>
            {notes.map((note) => (
              <button
                key={note.id}
                type="button"
                className="w-full rounded-xl border p-3 text-left transition-colors"
                style={{
                  borderColor: 'var(--color-border)',
                  background: note.id === activeNote?.id
                    ? 'var(--surface-selected)'
                    : 'var(--surface-list)',
                }}
                onClick={() => setActiveNoteId(note.id)}
              >
                <p className="font-medium text-[var(--color-text)]">{note.title}</p>
                <p className="mt-1 text-xs text-[var(--color-text-muted)]">{note.subject}</p>
                <p className="mt-1 text-xs text-[var(--color-text-muted)]">Updated {note.updatedAt}</p>
              </button>
            ))}
          </Card>
        </div>
        <div className="md:col-span-3">
          <Card glass className="space-y-4 min-h-[420px]">
            {activeNote ? (
              <>
                <div>
                  <h3 className="text-xl font-semibold text-[var(--color-text)]">{activeNote.title}</h3>
                  <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                    {activeNote.subject} | Last updated {activeNote.updatedAt}
                  </p>
                </div>
                <Textarea
                  className="min-h-[320px]"
                  value={activeNote.content}
                  placeholder="Write your study notes here..."
                  onChange={(event) => updateActiveNote(event.target.value)}
                />
              </>
            ) : (
              <p className="text-sm text-[var(--color-text-muted)]">Create your first note to start writing.</p>
            )}
          </Card>
        </div>
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Create Note">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            addNote()
          }}
        >
          <Input
            label="Title"
            value={form.title}
            placeholder="Chapter 5 summary"
            onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
          />
          <Select
            label="Subject"
            options={subjectOptions}
            value={form.subject}
            onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))}
          />
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Create</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
