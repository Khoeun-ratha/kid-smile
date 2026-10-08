import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import LoginView from '../views/LoginView.vue'
import CategoriesView from '../views/CategoriesView.vue'
import QuestionsView from '../views/QuestionsView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/categories' },
    { path: '/login', name: 'login', component: LoginView },
    { path: '/categories', name: 'categories', component: CategoriesView, meta: { requiresAuth: true } },
    { path: '/questions', name: 'questions', component: QuestionsView, meta: { requiresAuth: true } },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'login' }
  }
})

export default router
