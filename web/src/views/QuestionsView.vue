<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { api } from '../api'
import { useDataTools } from '../composables/useDataTools'
import { useContentLanguageStore } from '../stores/contentLanguage'
import LanguageTabs from '../components/LanguageTabs.vue'
import { LANGUAGES } from '../lib/languages'

const langStore = useContentLanguageStore()
const currentLang = computed({
  get: () => langStore.current,
  set: (code) => langStore.set(code),
})

const allCategories = ref([])
const allQuestions = ref([])
const loading = ref(true)
const filterCategoryId = ref('')
const error = ref('')
const status = ref('')
const editingId = ref(null)
const publishing = ref(false)
const form = reactive(blankForm())

const categories = computed(() => allCategories.value.filter((c) => c.language === currentLang.value))
const questions = computed(() =>
  allQuestions.value.filter(
    (q) => q.language === currentLang.value && (!filterCategoryId.value || q.category_id === filterCategoryId.value),
  ),
)

const {
  error: dataError,
  status: dataStatus,
  importing,
  resetting,
  importInput,
  exportJson,
  exportCsv,
  exportXlsx,
  triggerImport,
  onImportFile,
  resetAll,
} = useDataTools({
  reload: async () => {
    filterCategoryId.value = ''
    await load()
  },
  describeForReset: () => `${allCategories.value.length} categories and ${allQuestions.value.length} questions (all languages)`,
})

function blankForm() {
  return {
    category_id: '',
    prompt: '',
    choices: ['', '', '', ''],
    correct_index: 0,
    difficulty: 'easy',
    age_group: '4-6',
  }
}

async function load() {
  loading.value = true
  try {
    allCategories.value = await api.getCategories()
    allQuestions.value = await api.getQuestions()
  } finally {
    loading.value = false
  }
}

function onLanguageChange() {
  filterCategoryId.value = ''
}

function category(id) {
  return allCategories.value.find((c) => c.id === id)
}

function startCreate() {
  editingId.value = 'new'
  Object.assign(form, blankForm())
  if (filterCategoryId.value) form.category_id = filterCategoryId.value
}

function startEdit(question) {
  editingId.value = question.id
  Object.assign(form, { ...question, choices: [...question.choices] })
}

function cancel() {
  editingId.value = null
}

async function save() {
  error.value = ''
  try {
    const categoryId = Number(form.category_id)
    const payload = {
      ...form,
      category_id: categoryId,
      // A question always belongs to its category's language — no separate
      // picker, so it's impossible to file an English question under a
      // Khmer category (or vice versa) by mistake.
      language: category(categoryId)?.language ?? currentLang.value,
      correct_index: Number(form.correct_index),
    }
    if (editingId.value === 'new') {
      await api.createQuestion(payload)
    } else {
      await api.updateQuestion(editingId.value, payload)
    }
    editingId.value = null
    await load()
  } catch (e) {
    error.value = e.message
  }
}

async function remove(question) {
  if (!confirm('Delete this question?')) return
  await api.deleteQuestion(question.id)
  await load()
}

async function publish() {
  status.value = ''
  error.value = ''
  publishing.value = true
  try {
    const res = await api.publish()
    status.value = `Published! Mobile devices will now pull pack v${res.pack_version}.`
  } catch (e) {
    error.value = e.message
  } finally {
    publishing.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Questions</h2>
        <p>Edit the quiz bank, then publish to push a new pack to mobile devices.</p>
      </div>
      <div class="page-actions">
        <LanguageTabs v-model="currentLang" @update:modelValue="onLanguageChange" />
        <select class="input filter-select" v-model="filterCategoryId" @change="load">
          <option value="">All categories</option>
          <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.icon }} {{ c.name }}</option>
        </select>
        <button class="btn" @click="startCreate" :disabled="!categories.length">+ New question</button>
        <button class="btn btn-success" @click="publish" :disabled="publishing">
          {{ publishing ? 'Publishing…' : 'Publish' }}
        </button>
      </div>
    </div>

    <div class="data-toolbar">
      <span class="data-toolbar-label">Bulk data</span>
      <button class="btn btn-sm" @click="exportJson">Export JSON</button>
      <button class="btn btn-sm" @click="exportCsv" title="Plain text, easiest to hand-edit">Export CSV</button>
      <button class="btn btn-sm" @click="exportXlsx" title="Excel file, rows colored by category">
        Export Excel
      </button>
      <button class="btn btn-sm" @click="triggerImport" :disabled="importing">
        {{ importing ? 'Importing…' : 'Import JSON, CSV or Excel' }}
      </button>
      <input
        ref="importInput"
        type="file"
        accept="application/json,.csv,text/csv,.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        class="hidden-input"
        @change="onImportFile"
      />
      <button class="btn btn-sm btn-danger" @click="resetAll" :disabled="resetting">
        {{ resetting ? 'Resetting…' : 'Reset all' }}
      </button>
      <span class="data-toolbar-note">Bulk actions always cover every language, not just the tab above.</span>
    </div>

    <p v-if="error" class="alert alert-error">{{ error }}</p>
    <p v-if="status" class="alert alert-success">{{ status }}</p>
    <p v-if="dataError" class="alert alert-error">{{ dataError }}</p>
    <p v-if="dataStatus" class="alert alert-success">{{ dataStatus }}</p>

    <p v-if="!loading && !categories.length" class="alert alert-error">
      No {{ LANGUAGES.find((l) => l.code === currentLang)?.label }} categories yet — add one on the
      <RouterLink to="/categories">Categories</RouterLink> page before adding questions here.
    </p>

    <div class="card table-wrap">
      <table v-if="loading || questions.length">
        <thead>
          <tr>
            <th>Category</th>
            <th>Prompt</th>
            <th>Correct answer</th>
            <th>Difficulty</th>
            <th>Age</th>
            <th class="col-actions"></th>
          </tr>
        </thead>
        <tbody v-if="!loading">
          <tr v-for="q in questions" :key="q.id">
            <td>
              <span class="badge">{{ category(q.category_id)?.icon }} {{ category(q.category_id)?.name ?? '—' }}</span>
            </td>
            <td class="prompt-cell">{{ q.prompt }}</td>
            <td>{{ q.choices[q.correct_index] }}</td>
            <td><span class="badge badge-muted">{{ q.difficulty }}</span></td>
            <td><span class="badge badge-muted">{{ q.age_group }}</span></td>
            <td class="col-actions">
              <button class="btn btn-ghost btn-sm" @click="startEdit(q)">Edit</button>
              <button class="btn btn-danger btn-sm" @click="remove(q)">Delete</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="loading" class="empty-state">Loading questions…</div>
      <div v-else-if="!questions.length" class="empty-state">
        No {{ LANGUAGES.find((l) => l.code === currentLang)?.label }} questions
        {{ filterCategoryId ? 'in this category' : 'yet' }}. Add your first one to get started.
      </div>
    </div>

    <div v-if="editingId !== null" class="modal-backdrop" @click.self="cancel">
      <form class="modal" @submit.prevent="save">
        <h3>{{ editingId === 'new' ? 'New question' : 'Edit question' }} <span class="km-tag">{{ LANGUAGES.find((l) => l.code === currentLang)?.label }}</span></h3>

        <div class="field">
          <label>Category</label>
          <select class="input" v-model="form.category_id" required>
            <option disabled value="">Choose one</option>
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.icon }} {{ c.name }}</option>
          </select>
        </div>

        <div class="field">
          <label>Prompt</label>
          <textarea class="input" v-model="form.prompt" required></textarea>
        </div>

        <div class="field" v-for="(choice, i) in form.choices" :key="i">
          <label>Choice {{ i + 1 }}</label>
          <input class="input" v-model="form.choices[i]" required />
        </div>

        <div class="field">
          <label>Correct choice</label>
          <select class="input" v-model="form.correct_index">
            <option v-for="(choice, i) in form.choices" :key="i" :value="i">{{ choice || `Choice ${i + 1}` }}</option>
          </select>
        </div>

        <div class="row-2">
          <div class="field">
            <label>Difficulty</label>
            <select class="input" v-model="form.difficulty">
              <option value="easy">Easy</option>
              <option value="medium">Medium</option>
              <option value="hard">Hard</option>
            </select>
          </div>
          <div class="field">
            <label>Age group</label>
            <select class="input" v-model="form.age_group">
              <option value="4-6">4-6</option>
              <option value="7-9">7-9</option>
              <option value="10-12">10-12</option>
            </select>
          </div>
        </div>

        <div class="preview">
          <span class="preview-label">Preview</span>
          <p class="preview-prompt">{{ form.prompt || '(question text)' }}</p>
          <ul>
            <li v-for="(choice, i) in form.choices" :key="i" :class="{ correct: i === Number(form.correct_index) }">
              {{ choice || `Choice ${i + 1}` }}
            </li>
          </ul>
        </div>

        <div class="modal-actions">
          <button type="button" class="btn" @click="cancel">Cancel</button>
          <button type="submit" class="btn btn-primary">Save</button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
.filter-select {
  width: auto;
  min-width: 160px;
}
.prompt-cell {
  max-width: 320px;
}
.row-2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.km-tag {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  background: var(--color-primary-soft);
  color: var(--color-primary);
  vertical-align: middle;
}
.data-toolbar-note {
  font-size: 12px;
  color: var(--color-text-muted);
  margin-left: 4px;
}
.preview {
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 14px 16px;
}
.preview-label {
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);
}
.preview-prompt {
  margin: 8px 0 10px;
  font-weight: 600;
}
.preview ul {
  margin: 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.preview li {
  padding: 8px 10px;
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  font-size: 14px;
}
.preview li.correct {
  border-color: var(--color-success);
  color: var(--color-success);
  font-weight: 700;
}
</style>
