import { defineStore } from 'pinia'

// Which language's content (Categories/Questions) the admin is currently
// browsing — shared across both pages so switching tabs on one carries over
// to the other instead of resetting back to English every navigation.
export const useContentLanguageStore = defineStore('contentLanguage', {
  state: () => ({ current: 'en' }),
  actions: {
    set(code) {
      this.current = code
    },
  },
})
