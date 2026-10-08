import { useAuthStore } from './stores/auth'

const BASE_URL = import.meta.env.VITE_API_URL

async function request(path, { method = 'GET', body, auth = false } = {}) {
  const headers = { 'Content-Type': 'application/json' }
  if (auth) Object.assign(headers, useAuthStore().authHeader)

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  })

  if (!res.ok) {
    const detail = await res.json().catch(() => ({}))
    throw new Error(detail.detail || `Request failed (${res.status})`)
  }
  if (res.status === 204) return null
  return res.json()
}

export const api = {
  checkToken: () => request('/admin/check', { auth: true }),

  // Admin browsing always fetches every language and filters client-side
  // (the dataset is small) — language filtering server-side is for mobile's
  // pack fetch, which only ever wants one language on the device.
  getCategories: () => request('/categories'),
  createCategory: (data) => request('/categories', { method: 'POST', body: data, auth: true }),
  updateCategory: (id, data) => request(`/categories/${id}`, { method: 'PUT', body: data, auth: true }),
  deleteCategory: (id) => request(`/categories/${id}`, { method: 'DELETE', auth: true }),

  getQuestions: (categoryId) =>
    request(categoryId ? `/questions?category_id=${categoryId}` : '/questions'),
  createQuestion: (data) => request('/questions', { method: 'POST', body: data, auth: true }),
  updateQuestion: (id, data) => request(`/questions/${id}`, { method: 'PUT', body: data, auth: true }),
  deleteQuestion: (id) => request(`/questions/${id}`, { method: 'DELETE', auth: true }),

  publish: () => request('/publish', { method: 'POST', auth: true }),

  // Bulk export/import always covers every language — it's a backup/restore
  // of the whole admin dataset, not a mobile pack fetch.
  exportData: async () => {
    const [categories, questions] = await Promise.all([request('/categories'), request('/questions')])
    return { categories, questions }
  },
  importData: (data) => request('/admin/import', { method: 'POST', body: data, auth: true }),
  resetData: () => request('/admin/reset', { method: 'POST', auth: true }),
}
