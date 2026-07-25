import { StatusBar } from "expo-status-bar";
import { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View
} from "react-native";

import { ApiClient, ApiUser, Exercise, ExerciseTemplate, Workout, WorkoutSet } from "./src/api";
import { daysAgo, isoDate } from "./src/date";
import { ActiveWorkoutDraft, clearSession, loadDraft, loadSession, saveDraft, saveSession } from "./src/storage";

type Tab = "library" | "workout" | "history";

export default function App() {
  const [booting, setBooting] = useState(true);
  const [token, setToken] = useState<string | null>(null);
  const [user, setUser] = useState<ApiUser | null>(null);
  const [tab, setTab] = useState<Tab>("workout");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [search, setSearch] = useState("");
  const [templates, setTemplates] = useState<ExerciseTemplate[]>([]);
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [history, setHistory] = useState<Workout[]>([]);
  const [draft, setDraft] = useState<ActiveWorkoutDraft | null>(null);
  const [loading, setLoading] = useState(false);
  const [setForm, setSetForm] = useState({ exerciseId: "", weight: "", reps: "", kind: "working_set" });

  const api = useMemo(() => new ApiClient(token), [token]);

  useEffect(() => {
    async function boot() {
      const session = await loadSession();
      const savedDraft = await loadDraft();
      setToken(session.token);
      setUser(session.user);
      setDraft(savedDraft);
      setBooting(false);
    }

    boot().catch((error) => {
      Alert.alert("Startup failed", error.message);
      setBooting(false);
    });
  }, []);

  useEffect(() => {
    if (!token) return;
    refreshAppData().catch((error) => Alert.alert("Sync failed", error.message));
  }, [token]);

  useEffect(() => {
    saveDraft(draft).catch((error) => Alert.alert("Draft save failed", error.message));
  }, [draft]);

  async function refreshAppData() {
    setLoading(true);
    try {
      const [templateData, exerciseData, activeData, historyData] = await Promise.all([
        api.exerciseTemplates(search),
        api.exercises(),
        api.activeWorkouts(),
        api.history(daysAgo(30), isoDate(new Date()))
      ]);

      setTemplates(templateData);
      setExercises(exerciseData);
      setHistory(historyData);

      if (!draft && activeData.length > 0) {
        const active = activeData[0];
        setDraft({
          workoutId: active.id,
          startedAt: active.started_at,
          notes: active.notes || "",
          pendingSets: [],
          syncedSets: active.sets
        });
      }
    } finally {
      setLoading(false);
    }
  }

  async function handleLogin() {
    setLoading(true);
    try {
      const session = await api.login(email.trim(), password);
      setToken(session.token);
      setUser(session.user);
      await saveSession(session.token, session.user);
    } catch (error) {
      Alert.alert("Login failed", error instanceof Error ? error.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  async function handleLogout() {
    try {
      await api.logout();
    } finally {
      await clearSession();
      await saveDraft(null);
      setToken(null);
      setUser(null);
      setDraft(null);
      setExercises([]);
      setTemplates([]);
      setHistory([]);
    }
  }

  async function importTemplate(templateId: number) {
    const exercise = await api.addTemplate(templateId);
    setExercises((current) => [exercise, ...current.filter((item) => item.id !== exercise.id)]);
  }

  async function startWorkout() {
    const workout = await api.createWorkout("Mobile workout");
    setDraft({
      workoutId: workout.id,
      startedAt: workout.started_at,
      notes: workout.notes || "",
      pendingSets: [],
      syncedSets: workout.sets
    });
    setTab("workout");
  }

  async function addSet() {
    if (!draft?.workoutId) {
      Alert.alert("Start a workout first");
      return;
    }

    const exerciseId = Number(setForm.exerciseId);
    const reps = Number(setForm.reps);

    if (!exerciseId || !setForm.weight || !reps) {
      Alert.alert("Missing set details", "Choose an exercise and enter weight and reps.");
      return;
    }

    const pending = {
      localId: `${Date.now()}`,
      exerciseId,
      weight: setForm.weight,
      reps,
      kind: setForm.kind
    };

    setDraft((current) =>
      current ? { ...current, pendingSets: [...current.pendingSets, pending] } : current
    );

    try {
      const syncedSet = await api.createSet(draft.workoutId, {
        exercise_id: exerciseId,
        weight: setForm.weight,
        reps,
        kind: setForm.kind
      });

      setDraft((current) =>
        current
          ? {
              ...current,
              pendingSets: current.pendingSets.filter((item) => item.localId !== pending.localId),
              syncedSets: [...current.syncedSets, syncedSet]
            }
          : current
      );
      setSetForm({ exerciseId: "", weight: "", reps: "", kind: "working_set" });
      await refreshAppData();
    } catch (error) {
      Alert.alert("Set saved locally", error instanceof Error ? error.message : "It will remain in the draft.");
    }
  }

  if (booting) {
    return (
      <SafeAreaView style={styles.centered}>
        <ActivityIndicator />
      </SafeAreaView>
    );
  }

  if (!token || !user) {
    return (
      <SafeAreaView style={styles.screen}>
        <StatusBar style="dark" />
        <View style={styles.loginPanel}>
          <Text style={styles.brand}>FitTrack</Text>
          <TextInput
            autoCapitalize="none"
            keyboardType="email-address"
            placeholder="Email"
            style={styles.input}
            value={email}
            onChangeText={setEmail}
          />
          <TextInput
            placeholder="Password"
            secureTextEntry
            style={styles.input}
            value={password}
            onChangeText={setPassword}
          />
          <Pressable style={styles.primaryButton} onPress={handleLogin} disabled={loading}>
            <Text style={styles.primaryButtonText}>{loading ? "Signing in..." : "Sign in"}</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar style="dark" />
      <View style={styles.header}>
        <View>
          <Text style={styles.brandSmall}>FitTrack</Text>
          <Text style={styles.muted}>{user.email}</Text>
        </View>
        <Pressable onPress={handleLogout} style={styles.ghostButton}>
          <Text style={styles.ghostButtonText}>Sign out</Text>
        </Pressable>
      </View>

      <View style={styles.tabs}>
        {(["library", "workout", "history"] as Tab[]).map((item) => (
          <Pressable
            key={item}
            onPress={() => setTab(item)}
            style={[styles.tab, tab === item && styles.tabActive]}
          >
            <Text style={[styles.tabText, tab === item && styles.tabTextActive]}>{item}</Text>
          </Pressable>
        ))}
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {loading ? <ActivityIndicator style={styles.loading} /> : null}
        {tab === "library" ? (
          <LibraryScreen
            search={search}
            setSearch={setSearch}
            refresh={refreshAppData}
            templates={templates}
            importTemplate={importTemplate}
          />
        ) : null}
        {tab === "workout" ? (
          <WorkoutScreen
            draft={draft}
            exercises={exercises}
            setForm={setForm}
            setSetForm={setSetForm}
            startWorkout={startWorkout}
            addSet={addSet}
          />
        ) : null}
        {tab === "history" ? <HistoryScreen history={history} /> : null}
      </ScrollView>
    </SafeAreaView>
  );
}

function LibraryScreen({
  search,
  setSearch,
  refresh,
  templates,
  importTemplate
}: {
  search: string;
  setSearch: (value: string) => void;
  refresh: () => Promise<void>;
  templates: ExerciseTemplate[];
  importTemplate: (templateId: number) => Promise<void>;
}) {
  return (
    <View style={styles.stack}>
      <View style={styles.row}>
        <TextInput placeholder="Search exercises" style={[styles.input, styles.flex]} value={search} onChangeText={setSearch} />
        <Pressable style={styles.secondaryButton} onPress={refresh}>
          <Text style={styles.secondaryButtonText}>Search</Text>
        </Pressable>
      </View>
      {templates.map((template) => (
        <View style={styles.card} key={template.id}>
          <Text style={styles.cardTitle}>{template.name}</Text>
          <Text style={styles.muted}>
            {[template.primary_muscle, template.equipment, template.difficulty].filter(Boolean).join(" / ")}
          </Text>
          <Text style={styles.muted}>{template.media.length} cached media item(s)</Text>
          <Pressable style={styles.secondaryButton} onPress={() => importTemplate(template.id)}>
            <Text style={styles.secondaryButtonText}>Add to library</Text>
          </Pressable>
        </View>
      ))}
    </View>
  );
}

function WorkoutScreen({
  draft,
  exercises,
  setForm,
  setSetForm,
  startWorkout,
  addSet
}: {
  draft: ActiveWorkoutDraft | null;
  exercises: Exercise[];
  setForm: { exerciseId: string; weight: string; reps: string; kind: string };
  setSetForm: (value: { exerciseId: string; weight: string; reps: string; kind: string }) => void;
  startWorkout: () => Promise<void>;
  addSet: () => Promise<void>;
}) {
  const allSets: Array<WorkoutSet | { localId: string; exerciseId: number; weight: string; reps: number; kind: string }> = [
    ...(draft?.syncedSets || []),
    ...(draft?.pendingSets || [])
  ];

  return (
    <View style={styles.stack}>
      {!draft ? (
        <Pressable style={styles.primaryButton} onPress={startWorkout}>
          <Text style={styles.primaryButtonText}>Start workout</Text>
        </Pressable>
      ) : (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Active workout</Text>
          <Text style={styles.muted}>Started {new Date(draft.startedAt).toLocaleString()}</Text>
          <Text style={styles.muted}>{draft.pendingSets.length} pending local set(s)</Text>
        </View>
      )}

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Log set</Text>
        <TextInput
          placeholder="Exercise ID"
          keyboardType="number-pad"
          style={styles.input}
          value={setForm.exerciseId}
          onChangeText={(exerciseId) => setSetForm({ ...setForm, exerciseId })}
        />
        <TextInput
          placeholder="Weight"
          keyboardType="decimal-pad"
          style={styles.input}
          value={setForm.weight}
          onChangeText={(weight) => setSetForm({ ...setForm, weight })}
        />
        <TextInput
          placeholder="Reps"
          keyboardType="number-pad"
          style={styles.input}
          value={setForm.reps}
          onChangeText={(reps) => setSetForm({ ...setForm, reps })}
        />
        <Pressable style={styles.secondaryButton} onPress={addSet}>
          <Text style={styles.secondaryButtonText}>Save set</Text>
        </Pressable>
      </View>

      <Text style={styles.sectionTitle}>My exercises</Text>
      {exercises.map((exercise) => (
        <View style={styles.compactRow} key={exercise.id}>
          <Text style={styles.exerciseId}>#{exercise.id}</Text>
          <Text style={styles.flex}>{exercise.name}</Text>
          <Text style={styles.muted}>{exercise.equipment}</Text>
        </View>
      ))}

      <Text style={styles.sectionTitle}>Workout sets</Text>
      {allSets.map((set) => (
        <View style={styles.compactRow} key={"id" in set ? set.id : set.localId}>
          <Text style={styles.flex}>Exercise {"exercise_id" in set ? set.exercise_id : set.exerciseId}</Text>
          <Text>{set.weight} x {set.reps}</Text>
        </View>
      ))}
    </View>
  );
}

function HistoryScreen({ history }: { history: Workout[] }) {
  return (
    <View style={styles.stack}>
      {history.map((workout) => (
        <View style={styles.card} key={workout.id}>
          <Text style={styles.cardTitle}>{new Date(workout.started_at).toLocaleDateString()}</Text>
          <Text style={styles.muted}>{workout.sets.length} set(s)</Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#f7f7f2" },
  centered: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: "#f7f7f2" },
  header: {
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 12,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center"
  },
  brand: { fontSize: 40, fontWeight: "800", color: "#17324d", marginBottom: 28 },
  brandSmall: { fontSize: 24, fontWeight: "800", color: "#17324d" },
  loginPanel: { flex: 1, justifyContent: "center", padding: 24, gap: 12 },
  tabs: { flexDirection: "row", gap: 8, paddingHorizontal: 20, paddingBottom: 12 },
  tab: { flex: 1, borderRadius: 8, paddingVertical: 10, alignItems: "center", backgroundColor: "#e6e2d6" },
  tabActive: { backgroundColor: "#17324d" },
  tabText: { color: "#4f5d65", fontWeight: "700", textTransform: "capitalize" },
  tabTextActive: { color: "#ffffff" },
  content: { padding: 20, paddingBottom: 48 },
  stack: { gap: 14 },
  row: { flexDirection: "row", gap: 10, alignItems: "center" },
  compactRow: {
    flexDirection: "row",
    gap: 10,
    alignItems: "center",
    padding: 12,
    borderRadius: 8,
    backgroundColor: "#ffffff",
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#d8d5cb"
  },
  card: {
    gap: 10,
    borderRadius: 8,
    padding: 16,
    backgroundColor: "#ffffff",
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#d8d5cb"
  },
  cardTitle: { fontSize: 18, fontWeight: "800", color: "#17324d" },
  sectionTitle: { marginTop: 10, fontSize: 16, fontWeight: "800", color: "#17324d" },
  muted: { color: "#66747c" },
  input: {
    borderWidth: 1,
    borderColor: "#c9c5b8",
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    backgroundColor: "#ffffff"
  },
  flex: { flex: 1 },
  primaryButton: { borderRadius: 8, paddingVertical: 14, alignItems: "center", backgroundColor: "#d84f36" },
  primaryButtonText: { color: "#ffffff", fontWeight: "800" },
  secondaryButton: {
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    alignItems: "center",
    backgroundColor: "#17324d"
  },
  secondaryButtonText: { color: "#ffffff", fontWeight: "800" },
  ghostButton: { borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8, backgroundColor: "#e6e2d6" },
  ghostButtonText: { color: "#17324d", fontWeight: "800" },
  exerciseId: { color: "#d84f36", fontWeight: "800" },
  loading: { marginBottom: 12 }
});
