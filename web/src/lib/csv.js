// A spreadsheet-friendly alternative to the raw JSON pack format: one row
// per question, category referenced by name (not id) and the correct answer
// written as its actual text (not an index) — both far easier to type into
// Excel/Sheets than hand-crafting JSON. `language` tags which independent
// content set (English or Khmer) a row belongs to; a file can mix both —
// categories are deduplicated by (name, language) together.
export const CSV_COLUMNS = [
  'category',
  'category_icon',
  'category_color',
  'language',
  'prompt',
  'choice_1',
  'choice_2',
  'choice_3',
  'choice_4',
  'correct_choice',
  'difficulty',
  'age_group',
]

export function packToCsv(pack) {
  const categoryById = new Map(pack.categories.map((c) => [c.id, c]))
  const rows = pack.questions.map((q) => {
    const cat = categoryById.get(q.category_id)
    return [
      cat?.name ?? '',
      cat?.icon ?? '',
      cat?.color ?? '',
      q.language ?? cat?.language ?? 'en',
      q.prompt,
      ...q.choices,
      q.choices[q.correct_index] ?? '',
      q.difficulty,
      q.age_group,
    ]
  })
  return toCsvText([CSV_COLUMNS, ...rows])
}

/** Parses a questions CSV into the same {categories, questions} shape the
 * JSON import expects. Categories are created in order of first appearance,
 * keyed by (name, language) together, so the same category name can exist
 * once per language without colliding; icon/color only need to be filled in
 * on a category's first row (later rows for it can leave them blank). */
export function csvToImportPayload(csvText) {
  return rowsToImportPayload(parseCsv(csvText))
}

/** Same conversion as [csvToImportPayload], but starting from already-split
 * rows (arrays of cell strings) — shared with the Excel importer, which
 * reads cell values straight from the worksheet instead of parsing text. */
export function rowsToImportPayload(rawRows) {
  const rows = rawRows
    .map((row) => row.map((cell) => (cell ?? '').toString()))
    .filter((row) => row.some((cell) => cell.trim() !== ''))
  if (rows.length === 0) throw new Error('The file is empty.')

  const [header, ...dataRows] = rows
  const columnIndex = Object.fromEntries(header.map((h, i) => [h.trim().toLowerCase(), i]))
  const required = ['category', 'prompt', 'choice_1', 'choice_2', 'choice_3', 'choice_4', 'correct_choice']
  const missing = required.filter((col) => !(col in columnIndex))
  if (missing.length) {
    throw new Error(`Missing required column${missing.length > 1 ? 's' : ''}: ${missing.join(', ')}.`)
  }

  const cell = (row, name) => row[columnIndex[name]]?.trim() ?? ''

  const categories = []
  const categoryIdByKey = new Map()
  const questions = []

  dataRows.forEach((row, i) => {
    const rowNumber = i + 2 // +1 for the header row, +1 for 1-based counting
    const name = cell(row, 'category')
    if (!name) throw new Error(`Row ${rowNumber}: "category" is required.`)
    const language = cell(row, 'language') || 'en'

    const key = `${language}::${name}`
    let categoryId = categoryIdByKey.get(key)
    if (categoryId === undefined) {
      categoryId = categories.length + 1
      categoryIdByKey.set(key, categoryId)
      categories.push({
        id: categoryId,
        name,
        language,
        icon: cell(row, 'category_icon') || '❓',
        color: cell(row, 'category_color') || '#9E9E9E',
        sort_order: categories.length + 1,
      })
    }

    const choices = [1, 2, 3, 4].map((n) => cell(row, `choice_${n}`))
    if (choices.some((c) => !c)) throw new Error(`Row ${rowNumber}: all 4 choices are required.`)

    const prompt = cell(row, 'prompt')
    if (!prompt) throw new Error(`Row ${rowNumber}: "prompt" is required.`)

    const correctRaw = cell(row, 'correct_choice')
    const correctIndex = ['1', '2', '3', '4'].includes(correctRaw)
      ? Number(correctRaw) - 1
      : choices.indexOf(correctRaw)
    if (correctIndex < 0) {
      throw new Error(
        `Row ${rowNumber}: correct_choice "${correctRaw}" doesn't match any of the 4 choices (or use 1-4).`,
      )
    }

    questions.push({
      category_id: categoryId,
      prompt,
      choices,
      language,
      correct_index: correctIndex,
      difficulty: cell(row, 'difficulty') || 'easy',
      age_group: cell(row, 'age_group') || '4-6',
    })
  })

  return { categories, questions }
}

// -- RFC 4180-ish CSV, enough for Excel/Sheets exports: comma-separated,
// double-quote quoting, "" as an escaped quote inside a quoted field.

function parseCsv(text) {
  const rows = []
  let row = []
  let field = ''
  let inQuotes = false
  const normalized = text.replace(/\r\n/g, '\n')

  for (let i = 0; i < normalized.length; i++) {
    const char = normalized[i]
    if (inQuotes) {
      if (char === '"') {
        if (normalized[i + 1] === '"') {
          field += '"'
          i++
        } else {
          inQuotes = false
        }
      } else {
        field += char
      }
      continue
    }
    if (char === '"') {
      inQuotes = true
    } else if (char === ',') {
      row.push(field)
      field = ''
    } else if (char === '\n') {
      row.push(field)
      rows.push(row)
      row = []
      field = ''
    } else {
      field += char
    }
  }
  row.push(field)
  rows.push(row)
  return rows
}

function toCsvText(rows) {
  return rows.map((row) => row.map(escapeCsvField).join(',')).join('\r\n')
}

function escapeCsvField(value) {
  const s = String(value ?? '')
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}
