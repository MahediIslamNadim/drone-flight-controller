import { useEffect, useState } from 'react'
import { Plus } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import Modal from '../../components/ui/Modal'
import Badge from '../../components/ui/Badge'
import { type FlashcardDeck, loadFlashcards, loadSubjects, saveFlashcards } from '../../lib/studyData'

interface DeckFormState {
  title: string
  subject: string
  cardCount: string
}

function createDeckFormState() {
  return {
    title: '',
    subject: loadSubjects()[0]?.name ?? '',
    cardCount: '',
  }
}

export default function FlashcardsPage() {
  const [decks, setDecks] = useState<FlashcardDeck[]>(loadFlashcards)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<DeckFormState>(createDeckFormState)
  const [error, setError] = useState('')
  const subjects = loadSubjects()
  const hasSubjects = subjects.length > 0

  useEffect(() => {
    saveFlashcards(decks)
  }, [decks])

  function closeModal() {
    setForm(createDeckFormState())
    setError('')
    setIsModalOpen(false)
  }

  function addDeck() {
    const cardCount = Number(form.cardCount)

    if (!form.title.trim()) {
      setError('Deck title is required.')
      return
    }

    if (!form.subject) {
      setError('Add a subject first before creating decks.')
      return
    }

    if (Number.isNaN(cardCount) || cardCount <= 0) {
      setError('Card count must be greater than 0.')
      return
    }

    const nextDeck: FlashcardDeck = {
      id: `deck-${Date.now()}`,
      title: form.title.trim(),
      subject: form.subject,
      cardCount,
      dueCount: Math.min(cardCount, Math.max(3, Math.round(cardCount * 0.3))),
      mastery: 0,
    }

    setDecks((current) => [nextDeck, ...current])
    closeModal()
  }

  const subjectOptions = subjects.map((subject) => ({
    value: subject.name,
    label: subject.name,
  }))

  return (
    <div className="space-y-6">
      <PageHeader
        title="Flashcards"
        subtitle="Review and memorize key concepts with study decks."
        actions={
          <Button icon={<Plus size={18} />} type="button" onClick={() => setIsModalOpen(true)} disabled={!hasSubjects}>
            New Deck
          </Button>
        }
      />
      {!hasSubjects && (
        <Card glass className="text-sm text-[var(--color-text-muted)]">
          Add a subject first from the Subjects page to create flashcard decks with clear course context.
        </Card>
      )}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {decks.map((deck) => (
          <Card key={deck.id} hover glass className="space-y-4">
            <div className="flex items-center justify-between gap-3">
              <h3 className="text-lg font-semibold text-[var(--color-text)]">{deck.title}</h3>
              <Badge variant="info">{deck.mastery}%</Badge>
            </div>
            <p className="text-sm text-[var(--color-text-muted)]">{deck.subject}</p>
            <p className="text-sm text-[var(--color-text-muted)]">{deck.cardCount} cards total</p>
            <p className="text-sm text-[var(--color-text-muted)]">{deck.dueCount} cards due now</p>
          </Card>
        ))}
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Create Flashcard Deck">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            addDeck()
          }}
        >
          <Input
            label="Deck Title"
            value={form.title}
            placeholder="Organic Chemistry Terms"
            onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
          />
          <Select
            label="Subject"
            options={subjectOptions}
            value={form.subject}
            onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))}
          />
          <Input
            label="Card Count"
            type="number"
            min="1"
            value={form.cardCount}
            onChange={(event) => setForm((current) => ({ ...current, cardCount: event.target.value }))}
          />
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Create Deck</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
