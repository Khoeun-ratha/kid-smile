<script setup>
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()
const router = useRouter()

function logout() {
  auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="shell">
    <header v-if="auth.isAuthenticated" class="topbar">
      <div class="topbar-inner">
        <div class="brand">
          <span class="brand-mark">🙂</span>
          <span class="brand-name">Kid Smile <span class="brand-sub">Admin</span></span>
        </div>
        <nav>
          <RouterLink to="/categories">Categories</RouterLink>
          <RouterLink to="/questions">Questions</RouterLink>
        </nav>
        <button class="btn btn-ghost btn-sm logout" @click="logout">Log out</button>
      </div>
    </header>
    <main class="content">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.shell {
  min-height: 100vh;
}
.topbar {
  position: sticky;
  top: 0;
  z-index: 10;
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
}
.topbar-inner {
  max-width: 1040px;
  margin: 0 auto;
  padding: 14px 24px;
  display: flex;
  align-items: center;
  gap: 32px;
}
.brand {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 700;
  font-size: 16px;
}
.brand-mark {
  font-size: 20px;
}
.brand-sub {
  color: var(--color-text-muted);
  font-weight: 500;
}
nav {
  display: flex;
  gap: 4px;
  flex: 1;
}
nav a {
  text-decoration: none;
  color: var(--color-text-muted);
  font-weight: 600;
  font-size: 14px;
  padding: 8px 14px;
  border-radius: var(--radius-sm);
  transition: background 0.15s ease, color 0.15s ease;
}
nav a:hover {
  background: var(--color-bg);
  color: var(--color-text);
}
nav a.router-link-active {
  background: var(--color-primary-soft);
  color: var(--color-primary);
}
.logout {
  margin-left: auto;
}
.content {
  max-width: 1040px;
  margin: 0 auto;
  padding: 32px 24px 64px;
}
</style>
