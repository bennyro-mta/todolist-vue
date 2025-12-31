<template>
  <div style="max-width: 720px; margin: 24px auto; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;">
    <h1 style="margin: 0 0 16px;">Todo List</h1>

    <div style="display: flex; gap: 8px; align-items: center; margin-bottom: 12px;">
      <button @click="fetchTodos" :disabled="loading">Reload</button>
      <span v-if="loading" style="color: #555;">Loading…</span>
      <span v-if="error" style="color: #b00020;">{{ error }}</span>
    </div>

    <fieldset style="border: 1px solid #ddd; padding: 12px; margin-bottom: 16px;">
      <legend>Add Todo</legend>
      <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
        <input
          v-model="newTask"
          type="text"
          placeholder="Task description"
          style="flex: 1; min-width: 240px; padding: 6px;"
          @keyup.enter="addTodo"
        />
        <select v-model="newStatus" style="padding: 6px;">
          <option v-for="s in STATUS_OPTIONS" :key="s" :value="s">{{ s }}</option>
        </select>
        <button @click="addTodo" :disabled="loading">Add</button>
      </div>
    </fieldset>

    <div style="display: flex; gap: 8px; align-items: center; margin-bottom: 12px;">
      <label for="filter">Filter:</label>
      <select id="filter" v-model="filterStatus" style="padding: 6px;">
        <option value="">(all)</option>
        <option v-for="s in STATUS_OPTIONS" :key="s" :value="s">{{ s }}</option>
      </select>
    </div>

    <div v-if="filteredTodos.length === 0" style="color: #777; font-style: italic;">
      No todos to show.
    </div>

    <ul style="list-style: none; padding: 0; margin: 0;">
      <li
        v-for="todo in filteredTodos"
        :key="todo.id"
        style="border: 1px solid #eee; padding: 10px; margin-bottom: 8px; border-radius: 6px;"
      >
        <div style="display: flex; gap: 8px; align-items: center; justify-content: space-between; flex-wrap: wrap;">
          <div style="display: flex; flex-direction: column; gap: 4px; flex: 1;">
            <div style="display: flex; gap: 8px; align-items: center;">
              <strong>#{{ todo.id }}</strong>
              <input
                :value="todo.task"
                @change="updateTodoTask(todo, $event.target.value)"
                style="flex: 1; min-width: 240px; padding: 6px;"
              />
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <label>Status:</label>
              <select
                :value="todo.status || 'Todo'"
                @change="updateTodoStatus(todo, $event.target.value)"
                style="padding: 6px;"
              >
                <option v-for="s in STATUS_OPTIONS" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
          </div>
          <div>
            <button @click="deleteTodo(todo.id)" :disabled="loading" style="background: #b00020; color: white; border: none; padding: 8px 10px; border-radius: 4px;">
              Delete
            </button>
          </div>
        </div>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";

const STATUS_OPTIONS = ["Todo", "In Progress", "Complete"];

export default {
  name: "App",
  data() {
    const apiBase =
      (typeof window !== "undefined" &&
        window.APP_CONFIG &&
        window.APP_CONFIG.API_BASE_URL) ||
      import.meta.env.VITE_API_BASE_URL ||
      "/";
    // Simple startup logs to aid debugging
    console.log("[App.vue] Using API base URL:", apiBase);

    return {
      apiBase,
      http: axios.create({
        baseURL: apiBase,
        headers: { "Content-Type": "application/json" },
      }),
      todos: [],
      loading: false,
      error: null,
      newTask: "",
      newStatus: "Todo",
      filterStatus: "",
    };
  },
  computed: {
    STATUS_OPTIONS() {
      return STATUS_OPTIONS;
    },
    filteredTodos() {
      const status = (this.filterStatus || "").trim();
      if (!status) return this.todos;
      return this.todos.filter((t) => (t.status || "Todo") === status);
    },
  },
  async created() {
    console.log("[App.vue] created() lifecycle hook fired");
    await this.fetchTodos().catch((err) => {
      const msg = err?.message || "fetchTodos failed";
      console.error("[App.vue] created() fetchTodos error:", msg, err);
    });
  },
  methods: {
    _fmtErr(err, fallback) {
      const msg =
        err?.response?.data?.error ||
        err?.message ||
        fallback ||
        "Unexpected error";
      return msg;
    },
    async fetchTodos() {
      console.log("[App.vue] fetchTodos() -> GET /todos");
      this.loading = true;
      this.error = null;
      try {
        const { data } = await this.http.get("/todos");
        console.log("[App.vue] fetchTodos() response:", data);
        this.todos = Array.isArray(data)
          ? data.map((t) => ({ ...t, status: t.status || "Todo" }))
          : [];
      } catch (err) {
        const formatted = this._fmtErr(err, "Failed to load todos");
        console.error("[App.vue] fetchTodos() error:", formatted, err);
        this.error = formatted;
      } finally {
        this.loading = false;
        console.log(
          "[App.vue] fetchTodos() complete. loading=",
          this.loading,
          "todos=",
          this.todos.length
        );
      }
    },
    async addTodo() {
      const task = this.newTask.trim();
      console.log("[App.vue] addTodo() -> POST /todos", {
        task,
        desiredStatus: this.newStatus,
      });
      if (!task) {
        this.error = "Task cannot be empty";
        console.warn("[App.vue] addTodo() aborted: empty task");
        return;
      }
      this.loading = true;
      this.error = null;
      try {
        const { data } = await this.http.post("/todos", { task });
        const created = data;
        console.log("[App.vue] addTodo() created:", created);
        const desiredStatus = this.newStatus || "Todo";
        if (desiredStatus && desiredStatus !== created.status) {
          await this.http.patch(`/todos/${created.id}`, {
            status: desiredStatus,
          });
          created.status = desiredStatus;
          console.log("[App.vue] addTodo() status updated to:", desiredStatus);
        }
        this.todos.unshift(created);
        this.newTask = "";
        this.newStatus = "Todo";
      } catch (err) {
        const formatted = this._fmtErr(err, "Failed to add todo");
        console.error("[App.vue] addTodo() error:", formatted, err);
        this.error = formatted;
      } finally {
        this.loading = false;
      }
    },
    async updateTodoStatus(todo, status) {
      console.log("[App.vue] updateTodoStatus() -> PATCH /todos/:id", {
        id: todo.id,
        status,
      });
      if (!STATUS_OPTIONS.includes(status)) {
        this.error = "Invalid status";
        console.warn("[App.vue] updateTodoStatus() aborted: invalid status", status);
        return;
      }
      this.loading = true;
      this.error = null;
      try {
        await this.http.patch(`/todos/${todo.id}`, { status });
        todo.status = status;
      } catch (err) {
        const formatted = this._fmtErr(err, "Failed to update status");
        console.error("[App.vue] updateTodoStatus() error:", formatted, err);
        this.error = formatted;
      } finally {
        this.loading = false;
      }
    },
    async updateTodoTask(todo, newTask) {
      const task = String(newTask || "").trim();
      console.log("[App.vue] updateTodoTask() -> PATCH /todos/:id", {
        id: todo.id,
        task,
      });
      if (!task) {
        this.error = "Task cannot be empty";
        console.warn("[App.vue] updateTodoTask() aborted: empty task");
        return;
      }
      this.loading = true;
      this.error = null;
      try {
        await this.http.patch(`/todos/${todo.id}`, { task });
        todo.task = task;
      } catch (err) {
        const formatted = this._fmtErr(err, "Failed to update task");
        console.error("[App.vue] updateTodoTask() error:", formatted, err);
        this.error = formatted;
      } finally {
        this.loading = false;
      }
    },
    async deleteTodo(id) {
      console.log("[App.vue] deleteTodo() -> DELETE /todos/:id", { id });
      this.loading = true;
      this.error = null;
      try {
        await this.http.delete(`/todos/${id}`);
        this.todos = this.todos.filter((t) => t.id !== id);
      } catch (err) {
        const formatted = this._fmtErr(err, "Failed to delete todo");
        console.error("[App.vue] deleteTodo() error:", formatted, err);
        this.error = formatted;
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style>
/* You can add minimal styling or leave inline styles in the template */
</style>
