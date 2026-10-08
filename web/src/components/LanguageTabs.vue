<script setup>
import { LANGUAGES } from '../lib/languages'

defineProps({ modelValue: { type: String, required: true } })
defineEmits(['update:modelValue'])
</script>

<template>
  <div class="lang-tabs">
    <button
      v-for="lang in LANGUAGES"
      :key="lang.code"
      type="button"
      class="lang-tab"
      :class="{ active: modelValue === lang.code }"
      @click="$emit('update:modelValue', lang.code)"
    >
      {{ lang.label }}
    </button>
  </div>
</template>

<style scoped>
.lang-tabs {
  display: inline-flex;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  overflow: hidden;
}
.lang-tab {
  padding: 8px 16px;
  font: inherit;
  font-weight: 600;
  font-size: 14px;
  border: none;
  background: var(--color-surface);
  color: var(--color-text-muted);
  cursor: pointer;
}
.lang-tab + .lang-tab {
  border-left: 1px solid var(--color-border);
}
.lang-tab.active {
  background: var(--color-primary);
  color: white;
}
</style>
