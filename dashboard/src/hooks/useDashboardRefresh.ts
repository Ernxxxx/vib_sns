import { useState, useEffect, useCallback, useRef } from 'react';

export type RefreshFrequency = 0 | 1 | 10;

export const useDashboardRefresh = () => {
  const [refreshKey, setRefreshKey] = useState(0);
  const [frequency, setFrequency] = useState<RefreshFrequency>(0);
  const [nextRefreshInSeconds, setNextRefreshInSeconds] = useState<number | null>(null);
  const lastAutoTriggerRef = useRef(Date.now());

  const triggerRefresh = useCallback(() => {
    setRefreshKey((prev) => prev + 1);
  }, []);

  useEffect(() => {
    if (!frequency) {
      setNextRefreshInSeconds(null);
      lastAutoTriggerRef.current = Date.now();
      return;
    }
    const intervalDurationMs = frequency * 60 * 1000;
    lastAutoTriggerRef.current = Date.now();
    setNextRefreshInSeconds(frequency * 60);

    const autoInterval = setInterval(() => {
      setRefreshKey((prev) => prev + 1);
      lastAutoTriggerRef.current = Date.now();
    }, intervalDurationMs);

    const updateCountdown = () => {
      const nextTarget = lastAutoTriggerRef.current + intervalDurationMs;
      const remainingMs = nextTarget - Date.now();
      setNextRefreshInSeconds(Math.max(0, Math.ceil(remainingMs / 1000)));
    };

    updateCountdown();
    const countdownInterval = setInterval(updateCountdown, 1000);

    return () => {
      clearInterval(autoInterval);
      clearInterval(countdownInterval);
    };
  }, [frequency]);

  return {
    refreshKey,
    frequency,
    setFrequency: (value: RefreshFrequency) => setFrequency(value),
    triggerRefresh,
    nextRefreshInSeconds,
  };
};

