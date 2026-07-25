export type ApiUser = {
  id: number;
  email: string;
  confirmed_at: string | null;
};

export type ExerciseMedia = {
  id: number;
  kind: string;
  url: string;
  mime_type: string | null;
  width: number | null;
  height: number | null;
};

export type ExerciseTemplate = {
  id: number;
  name: string;
  primary_muscle: string | null;
  equipment: string | null;
  difficulty: string | null;
  media: ExerciseMedia[];
};

export type Exercise = {
  id: number;
  name: string;
  primary_muscle: string;
  equipment: string;
  media: ExerciseMedia[];
};

export type WorkoutSet = {
  id: number;
  workout_id: number;
  exercise_id: number;
  weight: string;
  reps: number;
  rpe: string | null;
  kind: string;
};

export type Workout = {
  id: number;
  started_at: string;
  notes: string | null;
  status: "active" | "completed";
  sets: WorkoutSet[];
};

type ApiEnvelope<T> = {
  data: T;
  pagination?: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
};

const defaultBaseUrl = "http://localhost:4000/api/v1";

export class ApiClient {
  private token: string | null;
  private baseUrl: string;

  constructor(token: string | null, baseUrl = process.env.EXPO_PUBLIC_API_BASE_URL || defaultBaseUrl) {
    this.token = token;
    this.baseUrl = baseUrl.replace(/\/$/, "");
  }

  setToken(token: string | null) {
    this.token = token;
  }

  async login(email: string, password: string) {
    const response = await this.request<ApiEnvelope<{ token: string; user: ApiUser }>>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password })
    });

    this.token = response.data.token;
    return response.data;
  }

  async logout() {
    if (!this.token) return;
    await this.request<void>("/auth/logout", { method: "DELETE" });
    this.token = null;
  }

  async me() {
    const response = await this.request<ApiEnvelope<ApiUser>>("/auth/me");
    return response.data;
  }

  async exerciseTemplates(search = "") {
    const query = search ? `?search=${encodeURIComponent(search)}` : "";
    const response = await this.request<ApiEnvelope<ExerciseTemplate[]>>(`/exercise-templates${query}`);
    return response.data;
  }

  async addTemplate(templateId: number) {
    const response = await this.request<ApiEnvelope<Exercise>>(`/exercise-templates/${templateId}/add`, {
      method: "POST"
    });

    return response.data;
  }

  async exercises() {
    const response = await this.request<ApiEnvelope<Exercise[]>>("/exercises");
    return response.data;
  }

  async activeWorkouts() {
    const response = await this.request<ApiEnvelope<Workout[]>>("/workouts/active");
    return response.data;
  }

  async createWorkout(notes = "") {
    const response = await this.request<ApiEnvelope<Workout>>("/workouts", {
      method: "POST",
      body: JSON.stringify({
        started_at: new Date().toISOString(),
        notes
      })
    });

    return response.data;
  }

  async createSet(workoutId: number, set: { exercise_id: number; weight: string; reps: number; kind: string }) {
    const response = await this.request<ApiEnvelope<WorkoutSet>>(`/workouts/${workoutId}/sets`, {
      method: "POST",
      body: JSON.stringify(set)
    });

    return response.data;
  }

  async history(startDate: string, endDate: string) {
    const response = await this.request<ApiEnvelope<Workout[]>>(
      `/history?start_date=${encodeURIComponent(startDate)}&end_date=${encodeURIComponent(endDate)}`
    );

    return response.data;
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const headers: Record<string, string> = {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(options.headers as Record<string, string> | undefined)
    };

    if (this.token) {
      headers.Authorization = `Bearer ${this.token}`;
    }

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...options,
      headers
    });

    if (response.status === 204) {
      return undefined as T;
    }

    const payload = await response.json();

    if (!response.ok) {
      const detail = payload?.errors?.detail || JSON.stringify(payload?.errors || payload);
      throw new Error(detail);
    }

    return payload as T;
  }
}
