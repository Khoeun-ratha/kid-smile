import { ref } from 'vue'
import { api } from '../api'
import { packToCsv, csvToImportPayload } from '../lib/csv'
import { packToXlsxBlob, xlsxToImportPayload } from '../lib/xlsx'

/** Export/Import/Reset for the shared category+question dataset — used by
 * both the Categories and Questions pages so the bulk-data toolbar behaves
 * identically wherever it's shown.
 *
 * @param {() => Promise<void>} reload - refreshes the calling view's data
 * @param {() => string} describeForReset - human text for what "Reset all"
 *   is about to delete, e.g. "5 categories and 26 questions"
 */
export function useDataTools({ reload, describeForReset }) {
  const error = ref('')
  const status = ref('')
  const importing = ref(false)
  const resetting = ref(false)
  const importInput = ref(null)

  async function exportJson() {
    error.value = ''
    try {
      const pack = await api.exportData()
      download(`kid-smile-pack-${today()}.json`, JSON.stringify(pack, null, 2), 'application/json')
    } catch (e) {
      error.value = e.message
    }
  }

  async function exportCsv() {
    error.value = ''
    try {
      const pack = await api.exportData()
      download(`kid-smile-questions-${today()}.csv`, packToCsv(pack), 'text/csv')
    } catch (e) {
      error.value = e.message
    }
  }

  async function exportXlsx() {
    error.value = ''
    try {
      const pack = await api.exportData()
      const blob = await packToXlsxBlob(pack)
      downloadBlob(`kid-smile-questions-${today()}.xlsx`, blob)
    } catch (e) {
      error.value = e.message
    }
  }

  function triggerImport() {
    importInput.value?.click()
  }

  async function onImportFile(event) {
    const file = event.target.files?.[0]
    event.target.value = '' // allow re-selecting the same file next time
    if (!file) return

    let payload
    try {
      const name = file.name.toLowerCase()
      if (name.endsWith('.csv')) {
        payload = csvToImportPayload(await file.text())
      } else if (name.endsWith('.xlsx')) {
        payload = await xlsxToImportPayload(await file.arrayBuffer())
      } else {
        payload = JSON.parse(await file.text())
      }
    } catch (e) {
      error.value = e.message || 'Could not read that file.'
      return
    }

    const categoryCount = payload.categories?.length ?? 0
    const questionCount = payload.questions?.length ?? 0
    const ok = confirm(
      `Import will replace ALL current categories and questions with ${categoryCount} categories and ` +
        `${questionCount} questions from this file. This can't be undone. Continue?`,
    )
    if (!ok) return

    error.value = ''
    status.value = ''
    importing.value = true
    try {
      await api.importData(payload)
      await reload()
      status.value = `Imported ${categoryCount} categories and ${questionCount} questions. Remember to Publish.`
    } catch (e) {
      error.value = e.message
    } finally {
      importing.value = false
    }
  }

  async function resetAll() {
    const ok = confirm(
      `Delete ALL ${describeForReset()}? This can't be undone unless you've exported a backup.`,
    )
    if (!ok) return

    error.value = ''
    status.value = ''
    resetting.value = true
    try {
      await api.resetData()
      await reload()
      status.value = 'All content deleted. Remember to Publish.'
    } catch (e) {
      error.value = e.message
    } finally {
      resetting.value = false
    }
  }

  return {
    error,
    status,
    importing,
    resetting,
    importInput,
    exportJson,
    exportCsv,
    exportXlsx,
    triggerImport,
    onImportFile,
    resetAll,
  }
}

function today() {
  return new Date().toISOString().slice(0, 10)
}

function download(filename, content, mime) {
  downloadBlob(filename, new Blob([content], { type: mime }))
}

function downloadBlob(filename, blob) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
