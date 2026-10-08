<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
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
const loading = ref(true)
const error = ref('')
const editingId = ref(null)
const form = reactive(blankForm())

const categories = computed(() => allCategories.value.filter((c) => c.language === currentLang.value))

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
  reload: load,
  describeForReset: () => `${allCategories.value.length} categories and their questions (all languages)`,
})

function blankForm() {
  return { name: '', language: 'en', icon: '', color: '#FF8A65', sort_order: 0 }
}

async function load() {
  loading.value = true
  try {
    allCategories.value = await api.getCategories()
  } finally {
    loading.value = false
  }
}

function startCreate() {
  editingId.value = 'new'
  Object.assign(form, blankForm(), { language: currentLang.value, sort_order: categories.value.length + 1 })
}

function startEdit(category) {
  editingId.value = category.id
  Object.assign(form, category)
}

function cancel() {
  editingId.value = null
}

async function save() {
  error.value = ''
  try {
    if (editingId.value === 'new') {
      await api.createCategory(form)
    } else {
      await api.updateCategory(editingId.value, form)
    }
    editingId.value = null
    await load()
  } catch (e) {
    error.value = e.message
  }
}

async function remove(category) {
  if (!confirm(`Delete "${category.name}" and all its questions?`)) return
  await api.deleteCategory(category.id)
  await load()
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Categories</h2>
        <p>Groups of questions kids pick from on the home screen.</p>
      </div>
      <div class="page-actions">
        <LanguageTabs v-model="currentLang" />
        <button class="btn btn-primary" @click="startCreate">+ New category</button>
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
    <p v-if="dataError" class="alert alert-error">{{ dataError }}</p>
    <p v-if="dataStatus" class="alert alert-success">{{ dataStatus }}</p>

    <div class="card table-wrap">
      <table v-if="loading || categories.length">
        <thead>
          <tr>
            <th></th>
            <th>Name</th>
            <th>Color</th>
            <th>Order</th>
            <th class="col-actions"></th>
          </tr>
        </thead>
        <tbody v-if="!loading">
          <tr v-for="c in categories" :key="c.id">
            <td><span class="icon-badge">{{ c.icon }}</span></td>
            <td><strong>{{ c.name }}</strong></td>
            <td>
              <span class="swatch" :style="{ background: c.color }"></span>
              <span class="badge badge-muted">{{ c.color }}</span>
            </td>
            <td>{{ c.sort_order }}</td>
            <td class="col-actions">
              <button class="btn btn-ghost btn-sm" @click="startEdit(c)">Edit</button>
              <button class="btn btn-danger btn-sm" @click="remove(c)">Delete</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="loading" class="empty-state">Loading categories…</div>
      <div v-else-if="!categories.length" class="empty-state">
        No {{ LANGUAGES.find((l) => l.code === currentLang)?.label }} categories yet. Create the first one to get
        started.
      </div>
    </div>

    <div v-if="editingId !== null" class="modal-backdrop" @click.self="cancel">
      <form class="modal" @submit.prevent="save">
        <h3>{{ editingId === 'new' ? 'New category' : 'Edit category' }}</h3>
        <div class="field">
          <label>Language</label>
          <select class="input" v-model="form.language" required>
            <option v-for="lang in LANGUAGES" :key="lang.code" :value="lang.code">{{ lang.label }}</option>
          </select>
        </div>
        <div class="field">
          <label>Name</label>
          <input class="input" v-model="form.name" required />
        </div>
        <div class="field">
          <label>Icon (emoji)</label>
          <input class="input" v-model="form.icon" required />
        </div>
        <div class="field">
          <label>Color</label>
          <input class="input" v-model="form.color" type="color" />
        </div>
        <div class="field">
          <label>Sort order</label>
          <input class="input" v-model.number="form.sort_order" type="number" />
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
.data-toolbar-note {
  font-size: 12px;
  color: var(--color-text-muted);
  margin-left: 4px;
}
</style>
