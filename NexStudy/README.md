# NexStudy

NexStudy is a study management dashboard built with React, TypeScript, Vite, and Tailwind CSS.

## Current Scope

- Dashboard shell with routed study tools
- Functional `Subjects` management with local persistence
- Functional `Study Tracker` with session logging and subject-hour sync
- Analytics, planner, notes, flashcards, timetable, reminders, timer, goals, and settings pages ready for further feature work

## Tech Stack

- React 19
- TypeScript
- Vite
- React Router
- Tailwind CSS
- Recharts

## Scripts

```bash
npm run dev
npm run build
npm run lint
npm run preview
```

## Project Structure

```text
src/
  app/                app bootstrap, providers, routing
  components/         shared layout, UI, and chart components
  features/           page-level feature modules
  styles/             global styles and design tokens
```

## Notes

- Data for the current `Subjects` and `Tracker` flows is stored in `localStorage`.
- This project is currently frontend-only.
