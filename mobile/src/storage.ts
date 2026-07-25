import AsyncStorage from "@react-native-async-storage/async-storage";

import type { ApiUser, WorkoutSet } from "./api";

const tokenKey = "fittrack.mobile.token";
const userKey = "fittrack.mobile.user";
const draftKey = "fittrack.mobile.activeDraft";

export type ActiveWorkoutDraft = {
  workoutId: number | null;
  startedAt: string;
  notes: string;
  pendingSets: Array<{
    localId: string;
    exerciseId: number;
    weight: string;
    reps: number;
    kind: string;
  }>;
  syncedSets: WorkoutSet[];
};

export async function saveSession(token: string, user: ApiUser) {
  await AsyncStorage.multiSet([
    [tokenKey, token],
    [userKey, JSON.stringify(user)]
  ]);
}

export async function loadSession() {
  const pairs = await AsyncStorage.multiGet([tokenKey, userKey]);
  const token = pairs.find(([key]) => key === tokenKey)?.[1] || null;
  const userJson = pairs.find(([key]) => key === userKey)?.[1] || null;

  return {
    token,
    user: userJson ? (JSON.parse(userJson) as ApiUser) : null
  };
}

export async function clearSession() {
  await AsyncStorage.multiRemove([tokenKey, userKey]);
}

export async function saveDraft(draft: ActiveWorkoutDraft | null) {
  if (!draft) {
    await AsyncStorage.removeItem(draftKey);
    return;
  }

  await AsyncStorage.setItem(draftKey, JSON.stringify(draft));
}

export async function loadDraft() {
  const value = await AsyncStorage.getItem(draftKey);
  return value ? (JSON.parse(value) as ActiveWorkoutDraft) : null;
}
