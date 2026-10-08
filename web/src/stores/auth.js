import { defineStore } from 'pinia'

// Token lives only in memory (a Pinia store, not localStorage/sessionStorage)
// so an admin credential never sits on disk in the browser — logging out or
// closing the tab clears it, and each session re-enters it deliberately.
export const useAuthStore = defineStore('auth', {
  state: () => ({ token: '' }),
  getters: {
    isAuthenticated: (state) => state.token.length > 0,
    authHeader: (state) => (state.token ? { Authorization: `Bearer ${state.token}` } : {}),
  },
  actions: {
    login(token) {
      this.token = token
    },
    logout() {
      this.token = ''
    },
  },
})
