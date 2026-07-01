import { useEffect, useEffectEvent, useState } from 'react'
import { subscribeToStudyData, type StudyStorageKey } from './studyData'

export function useStudyLiveValue<T>(loader: () => T, watchedKeys: StudyStorageKey[]) {
  const [value, setValue] = useState(loader)
  const refreshValue = useEffectEvent(() => {
    setValue(loader())
  })

  useEffect(() => {
    return subscribeToStudyData(() => {
      refreshValue()
    }, watchedKeys)
  }, [watchedKeys])

  return value
}
