import ExcelJS from 'exceljs'
import { CSV_COLUMNS, rowsToImportPayload } from './csv'

const HEADER_LABELS = {
  category: 'Category',
  category_icon: 'Icon',
  category_color: 'Color',
  language: 'Language',
  prompt: 'Prompt',
  choice_1: 'Choice 1',
  choice_2: 'Choice 2',
  choice_3: 'Choice 3',
  choice_4: 'Choice 4',
  correct_choice: 'Correct answer',
  difficulty: 'Difficulty',
  age_group: 'Age group',
}

// Reverse of HEADER_LABELS, so a sheet exported with the pretty column
// titles above reads back into the same internal keys the CSV importer uses.
const LABEL_TO_KEY = Object.fromEntries(
  Object.entries(HEADER_LABELS).map(([key, label]) => [label.toLowerCase(), key]),
)

/** Same data as the CSV export, but as a real .xlsx workbook: each
 * question's row is filled with its category's color, so the sheet reads
 * like the color-coded category tiles in the app instead of plain text. */
export async function packToXlsxBlob(pack) {
  const workbook = new ExcelJS.Workbook()
  workbook.creator = 'Kid Smile Admin'
  const sheet = workbook.addWorksheet('Questions', {
    views: [{ state: 'frozen', ySplit: 1 }],
  })

  sheet.columns = CSV_COLUMNS.map((key) => ({
    header: HEADER_LABELS[key] ?? key,
    key,
    width: columnWidth(key),
  }))

  const headerRow = sheet.getRow(1)
  headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } }
  headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF374151' } }
  headerRow.alignment = { vertical: 'middle' }
  headerRow.height = 20

  const categoryById = new Map(pack.categories.map((c) => [c.id, c]))
  pack.questions.forEach((q) => {
    const cat = categoryById.get(q.category_id)
    const row = sheet.addRow({
      category: cat?.name ?? '',
      category_icon: cat?.icon ?? '',
      category_color: cat?.color ?? '',
      language: q.language ?? cat?.language ?? 'en',
      prompt: q.prompt,
      choice_1: q.choices[0] ?? '',
      choice_2: q.choices[1] ?? '',
      choice_3: q.choices[2] ?? '',
      choice_4: q.choices[3] ?? '',
      correct_choice: q.choices[q.correct_index] ?? '',
      difficulty: q.difficulty,
      age_group: q.age_group,
    })

    const fillColor = toArgb(cat?.color)
    if (fillColor) {
      row.eachCell((cell) => {
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: fillColor } }
      })
    }
    row.getCell('correct_choice').font = { bold: true, color: { argb: 'FF1B5E20' } }
    row.alignment = { wrapText: true, vertical: 'top' }
  })

  const lastColumn = String.fromCharCode(64 + CSV_COLUMNS.length)
  sheet.autoFilter = { from: 'A1', to: `${lastColumn}1` }

  const buffer = await workbook.xlsx.writeBuffer()
  return new Blob([buffer], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
}

/** Reads an uploaded .xlsx file's first sheet and converts it the same way
 * [csvToImportPayload] converts a CSV — cell values only, styling is
 * ignored (it's there for the human reading the sheet, not for re-import). */
export async function xlsxToImportPayload(arrayBuffer) {
  const workbook = new ExcelJS.Workbook()
  await workbook.xlsx.load(arrayBuffer)
  const sheet = workbook.worksheets[0]
  if (!sheet) throw new Error('The workbook has no sheets.')

  const rows = []
  sheet.eachRow({ includeEmpty: false }, (row) => {
    // ExcelJS rows are 1-indexed with row.values[0] unused.
    rows.push(row.values.slice(1).map(cellToString))
  })

  // Translate the pretty header labels ("Choice 1") back into the internal
  // column keys ("choice_1") that rowsToImportPayload matches against.
  if (rows.length > 0) {
    rows[0] = rows[0].map((cell) => LABEL_TO_KEY[cell.trim().toLowerCase()] ?? cell)
  }

  return rowsToImportPayload(rows)
}

function cellToString(value) {
  if (value == null) return ''
  if (typeof value === 'object') {
    if (Array.isArray(value.richText)) return value.richText.map((r) => r.text).join('')
    if (value.text != null) return String(value.text)
    if (value.result != null) return String(value.result) // formula result
  }
  return String(value)
}

function toArgb(hex) {
  if (!hex || !/^#?[0-9a-fA-F]{6}$/.test(hex)) return null
  return `FF${hex.replace('#', '').toUpperCase()}`
}

function columnWidth(key) {
  if (key === 'prompt') return 40
  if (key.startsWith('choice_')) return 18
  if (key === 'category') return 14
  return 12
}
