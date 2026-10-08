<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { api } from '../api'

const router = useRouter()
const auth = useAuthStore()
const token = ref('')
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  loading.value = true
  auth.login(token.value)
  try {
    await api.checkToken()
    router.push('/categories')
  } catch (e) {
    auth.logout()
    error.value = 'Invalid admin token.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-card card">
      <div class="brand-mark">🙂</div>
      <h1>Kid Smile Admin</h1>
      <p class="subtitle">Sign in to manage quiz categories and questions.</p>
      <form @submit.prevent="submit">
        <div class="field">
          <label for="token">Admin token</label>
          <input id="token" class="input" v-model="token" type="password" placeholder="Enter admin token" autofocus />
        </div>
        <button class="btn btn-primary" type="submit" :disabled="loading">
          {{ loading ? 'Signing in…' : 'Log in' }}
        </button>
      </form>
      <p v-if="error" class="alert alert-error">{{ error }}</p>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.login-card {
  width: 100%;
  max-width: 360px;
  padding: 36px 32px;
  text-align: center;
}
.brand-mark {
  font-size: 40px;
  margin-bottom: 8px;
}
h1 {
  margin: 0 0 6px;
  font-size: 20px;
}
.subtitle {
  margin: 0 0 24px;
  color: var(--color-text-muted);
  font-size: 14px;
}
form {
  display: flex;
  flex-direction: column;
  gap: 16px;
  text-align: left;
}
.btn {
  width: 100%;
  padding: 11px;
}
.alert {
  margin: 16px 0 0;
}
</style>
