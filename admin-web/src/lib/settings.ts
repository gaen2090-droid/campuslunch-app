const ALGO_KEY = "cl_use_algorithm_ranking";

export function getUseAlgorithmRanking(): boolean {
  const raw = localStorage.getItem(ALGO_KEY);
  if (raw === null) return true;
  return raw === "true";
}

export function setUseAlgorithmRanking(value: boolean): void {
  localStorage.setItem(ALGO_KEY, String(value));
}
