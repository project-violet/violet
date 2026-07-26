import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ViewMode = 'vertical' | 'horizontal';
export type PageMode = 'scroll' | 'paged';
export type ReadDirection = 'ltr' | 'rtl';
export type CoverPageMode = 'cover' | 'normal';
export type ViewerProfileName = 'mobile' | 'desktop';
export type ViewerProfilePreference = 'auto' | ViewerProfileName;

export interface ViewerProfileSettings {
  viewMode: ViewMode;
  pageMode: PageMode;
  readDirection: ReadDirection;
  padding: number;
  twoPageMode: boolean;
  coverPageMode: CoverPageMode;
}

interface ViewerState extends ViewerProfileSettings {
  profiles: Record<ViewerProfileName, ViewerProfileSettings>;
  profilePreference: ViewerProfilePreference;
  detectedProfile: ViewerProfileName;
  activeProfile: ViewerProfileName;
  showOverlay: boolean;
  showSettings: boolean;
  resumePromptEnabled: boolean;

  setProfilePreference: (preference: ViewerProfilePreference) => void;
  setDetectedProfile: (profile: ViewerProfileName) => void;
  setViewMode: (mode: ViewMode) => void;
  setPageMode: (mode: PageMode) => void;
  setReadDirection: (dir: ReadDirection) => void;
  setPadding: (padding: number) => void;
  toggleOverlay: () => void;
  setTwoPageMode: (enabled: boolean) => void;
  setCoverPageMode: (mode: CoverPageMode) => void;
  toggleSettings: () => void;
  setResumePromptEnabled: (enabled: boolean) => void;
}

const DESKTOP_DEFAULTS: ViewerProfileSettings = {
  viewMode: 'vertical',
  pageMode: 'paged',
  readDirection: 'rtl',
  padding: 0,
  twoPageMode: true,
  coverPageMode: 'cover',
};

const MOBILE_DEFAULTS: ViewerProfileSettings = {
  viewMode: 'vertical',
  pageMode: 'scroll',
  readDirection: 'rtl',
  padding: 0,
  twoPageMode: false,
  coverPageMode: 'cover',
};

function profileFields(profile: ViewerProfileSettings): ViewerProfileSettings {
  return {
    viewMode: profile.viewMode,
    pageMode: profile.pageMode,
    readDirection: profile.readDirection,
    padding: profile.padding,
    twoPageMode: profile.twoPageMode,
    coverPageMode: profile.coverPageMode,
  };
}

export const useViewerStore = create<ViewerState>()(
  persist(
    (set) => ({
      ...DESKTOP_DEFAULTS,
      profiles: {
        mobile: { ...MOBILE_DEFAULTS },
        desktop: { ...DESKTOP_DEFAULTS },
      },
      profilePreference: 'auto',
      detectedProfile: 'desktop',
      activeProfile: 'desktop',
      showOverlay: false,
      showSettings: false,
      resumePromptEnabled: true,

      setProfilePreference: (profilePreference) =>
        set((state) => {
          const activeProfile =
            profilePreference === 'auto' ? state.detectedProfile : profilePreference;
          return {
            profilePreference,
            activeProfile,
            ...profileFields(state.profiles[activeProfile]),
          };
        }),
      setDetectedProfile: (detectedProfile) =>
        set((state) => {
          if (state.detectedProfile === detectedProfile) return state;
          if (state.profilePreference !== 'auto') {
            return { detectedProfile };
          }
          return {
            detectedProfile,
            activeProfile: detectedProfile,
            ...profileFields(state.profiles[detectedProfile]),
          };
        }),
      setViewMode: (viewMode) =>
        set((state) => ({
          viewMode,
          profiles: {
            ...state.profiles,
            [state.activeProfile]: { ...state.profiles[state.activeProfile], viewMode },
          },
        })),
      setPageMode: (pageMode) =>
        set((state) => ({
          pageMode,
          profiles: {
            ...state.profiles,
            [state.activeProfile]: { ...state.profiles[state.activeProfile], pageMode },
          },
        })),
      setReadDirection: (readDirection) =>
        set((state) => ({
          readDirection,
          profiles: {
            ...state.profiles,
            [state.activeProfile]: { ...state.profiles[state.activeProfile], readDirection },
          },
        })),
      setPadding: (padding) =>
        set((state) => ({
          padding,
          profiles: {
            ...state.profiles,
            [state.activeProfile]: { ...state.profiles[state.activeProfile], padding },
          },
        })),
      toggleOverlay: () => set((state) => ({ showOverlay: !state.showOverlay })),
      setTwoPageMode: (twoPageMode) =>
        set((state) => ({
          twoPageMode,
          profiles: {
            ...state.profiles,
            [state.activeProfile]: { ...state.profiles[state.activeProfile], twoPageMode },
          },
        })),
      setCoverPageMode: (coverPageMode) =>
        set((state) => ({
          coverPageMode,
          profiles: {
            ...state.profiles,
            [state.activeProfile]: { ...state.profiles[state.activeProfile], coverPageMode },
          },
        })),
      toggleSettings: () => set((state) => ({ showSettings: !state.showSettings })),
      setResumePromptEnabled: (resumePromptEnabled) => set({ resumePromptEnabled }),
    }),
    {
      name: 'violet-viewer-settings',
      version: 1,
      migrate: (persistedState, version) => {
        const previous = persistedState as Partial<ViewerState>;
        if (version >= 1 && previous.profiles) {
          return previous as ViewerState;
        }

        const legacyDesktop: ViewerProfileSettings = {
          viewMode: previous.viewMode ?? DESKTOP_DEFAULTS.viewMode,
          pageMode: previous.pageMode ?? DESKTOP_DEFAULTS.pageMode,
          readDirection: previous.readDirection ?? DESKTOP_DEFAULTS.readDirection,
          padding: previous.padding ?? DESKTOP_DEFAULTS.padding,
          twoPageMode: previous.twoPageMode ?? DESKTOP_DEFAULTS.twoPageMode,
          coverPageMode: previous.coverPageMode ?? DESKTOP_DEFAULTS.coverPageMode,
        };

        return {
          ...previous,
          ...legacyDesktop,
          profiles: {
            mobile: { ...MOBILE_DEFAULTS },
            desktop: legacyDesktop,
          },
          profilePreference: 'auto',
          detectedProfile: 'desktop',
          activeProfile: 'desktop',
          showOverlay: false,
          showSettings: false,
        } as ViewerState;
      },
      partialize: (state) => ({
        ...state,
        showOverlay: false,
        showSettings: false,
      }),
    },
  ),
);
