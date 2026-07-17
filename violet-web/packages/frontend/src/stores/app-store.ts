import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import i18n from '../i18n/config';

export type ContentLanguage = 'all' | 'korean' | 'english' | 'japanese' | 'chinese';
export type UILanguage = 'system' | 'en' | 'ko' | 'ja' | 'zh';
export type ThemeColor =
  | 'purple' | 'amber' | 'black' | 'blue' | 'blueGrey' | 'brown'
  | 'cyan' | 'deepOrange' | 'deepPurple' | 'green' | 'grey'
  | 'indigo' | 'lightBlue' | 'lightGreen' | 'lime' | 'orange'
  | 'pink' | 'red' | 'teal' | 'yellow';
export type ThemeMode = 'dark' | 'light' | 'system';

export type ViewMode = 'grid' | 'detail';
export type ScrollMode = 'pagination' | 'infinite';
export type TagClickAction = 'search' | 'dialog';

interface AppState {
  contentLanguage: ContentLanguage;
  uiLanguage: UILanguage;
  themeColor: ThemeColor;
  themeMode: ThemeMode;
  sidebarCollapsed: boolean;
  viewMode: ViewMode;
  cardMinWidth: number;
  cropColumnWidth: number;
  scrollMode: ScrollMode;
  tagClickAction: TagClickAction;
  tagTranslation: boolean;
  aiSearchEnabled: boolean;
  messageSearchEnabled: boolean;
  messageSearchServerUrl: string;
  messageSearchResultLimit: number;
  messageSearchColumnWidth: number;
  llmSearchEnabled: boolean;
  llmSearchServerUrl: string;
  llmSearchTopK: number;
  llmSearchCandidateK: number;
  llmSearchColumnWidth: number;
  keywordGraphServerUrl: string;
  excludedTags: string[];
  imageCacheEnabled: boolean;
  imageCacheMaxSizeMB: number;
  imageCacheExpireDays: number;
  contextualSuggestionCounts: boolean;
  developerMode: boolean;
  hmacSalt: string;
  serverHost: string;

  setContentLanguage: (lang: ContentLanguage) => void;
  setUILanguage: (lang: UILanguage) => void;
  setThemeColor: (color: ThemeColor) => void;
  setThemeMode: (mode: ThemeMode) => void;
  toggleSidebar: () => void;
  setViewMode: (mode: ViewMode) => void;
  setCardMinWidth: (width: number) => void;
  setCropColumnWidth: (width: number) => void;
  setScrollMode: (mode: ScrollMode) => void;
  setTagClickAction: (action: TagClickAction) => void;
  setTagTranslation: (enabled: boolean) => void;
  setAiSearchEnabled: (enabled: boolean) => void;
  setMessageSearchEnabled: (enabled: boolean) => void;
  setMessageSearchServerUrl: (url: string) => void;
  setMessageSearchResultLimit: (limit: number) => void;
  setMessageSearchColumnWidth: (width: number) => void;
  setLlmSearchEnabled: (enabled: boolean) => void;
  setLlmSearchServerUrl: (url: string) => void;
  setLlmSearchTopK: (value: number) => void;
  setLlmSearchCandidateK: (value: number) => void;
  setLlmSearchColumnWidth: (width: number) => void;
  setKeywordGraphServerUrl: (url: string) => void;
  addExcludedTag: (tag: string) => void;
  removeExcludedTag: (tag: string) => void;
  setImageCacheEnabled: (enabled: boolean) => void;
  setImageCacheMaxSizeMB: (size: number) => void;
  setImageCacheExpireDays: (days: number) => void;
  setContextualSuggestionCounts: (enabled: boolean) => void;
  setDeveloperMode: (enabled: boolean) => void;
  setHmacSalt: (salt: string) => void;
  setServerHost: (host: string) => void;
}

// Helper to get system language
const getSystemLanguage = (): string => {
  const browserLang = navigator.language.toLowerCase();
  if (browserLang.startsWith('ko')) return 'ko';
  if (browserLang.startsWith('ja')) return 'ja';
  if (browserLang.startsWith('zh')) return 'zh';
  return 'en';
};

const getDefaultContentLanguage = (): ContentLanguage => {
  const lang = getSystemLanguage();
  const map: Record<string, ContentLanguage> = {
    ko: 'korean',
    ja: 'japanese',
    zh: 'chinese',
    en: 'english',
  };
  return map[lang] || 'all';
};

const getDefaultTagTranslation = (): boolean => {
  return getSystemLanguage() === 'ko';
};

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      contentLanguage: getDefaultContentLanguage(),
      uiLanguage: 'system',
      themeColor: 'purple',
      themeMode: 'dark',
      sidebarCollapsed: false,
      viewMode: 'grid',
      cardMinWidth: 200,
      cropColumnWidth: 240,
      scrollMode: 'pagination',
      tagClickAction: 'search',
      tagTranslation: getDefaultTagTranslation(),
      aiSearchEnabled: false,
      messageSearchEnabled: true,
      messageSearchServerUrl: 'http://127.0.0.1:12332',
      messageSearchResultLimit: 100,
      messageSearchColumnWidth: 420,
      llmSearchEnabled: true,
      llmSearchServerUrl: 'http://127.0.0.1:8788',
      llmSearchTopK: 10,
      llmSearchCandidateK: 500,
      llmSearchColumnWidth: 420,
      keywordGraphServerUrl: 'http://127.0.0.1:8787',
      excludedTags: ['female:snuff', 'female:gore'],
      imageCacheEnabled: true,
      imageCacheMaxSizeMB: 500,
      imageCacheExpireDays: 7,
      contextualSuggestionCounts: false,
      developerMode: false,
      hmacSalt: '',
      serverHost: 'https://koromo.cc',

      setContentLanguage: (contentLanguage) => set({ contentLanguage }),
      setUILanguage: (uiLanguage) => {
        const actualLang = uiLanguage === 'system' ? getSystemLanguage() : uiLanguage;
        i18n.changeLanguage(actualLang);
        set({ uiLanguage });
      },
      setThemeColor: (themeColor) => set({ themeColor }),
      setThemeMode: (themeMode) => set({ themeMode }),
      toggleSidebar: () => set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
      setViewMode: (viewMode) => set({ viewMode }),
      setCardMinWidth: (cardMinWidth) => set({ cardMinWidth }),
      setCropColumnWidth: (cropColumnWidth) => set({ cropColumnWidth }),
      setScrollMode: (scrollMode) => set({ scrollMode }),
      setTagClickAction: (tagClickAction) => set({ tagClickAction }),
      setTagTranslation: (tagTranslation) => set({ tagTranslation }),
      setAiSearchEnabled: (aiSearchEnabled) => set({ aiSearchEnabled }),
      setMessageSearchEnabled: (messageSearchEnabled) => set({ messageSearchEnabled }),
      setMessageSearchServerUrl: (messageSearchServerUrl) => set({ messageSearchServerUrl }),
      setMessageSearchResultLimit: (messageSearchResultLimit) => set({ messageSearchResultLimit }),
      setMessageSearchColumnWidth: (messageSearchColumnWidth) => set({ messageSearchColumnWidth }),
      setLlmSearchEnabled: (llmSearchEnabled) => set({ llmSearchEnabled }),
      setLlmSearchServerUrl: (llmSearchServerUrl) => set({ llmSearchServerUrl }),
      setLlmSearchTopK: (llmSearchTopK) => set({ llmSearchTopK }),
      setLlmSearchCandidateK: (llmSearchCandidateK) => set({ llmSearchCandidateK }),
      setLlmSearchColumnWidth: (llmSearchColumnWidth) => set({ llmSearchColumnWidth }),
      setKeywordGraphServerUrl: (keywordGraphServerUrl) => set({ keywordGraphServerUrl }),
      addExcludedTag: (tag) =>
        set((state) => ({
          excludedTags: state.excludedTags.includes(tag)
            ? state.excludedTags
            : [...state.excludedTags, tag],
        })),
      removeExcludedTag: (tag) =>
        set((state) => ({
          excludedTags: state.excludedTags.filter((t) => t !== tag),
        })),
      setImageCacheEnabled: (imageCacheEnabled) => set({ imageCacheEnabled }),
      setImageCacheMaxSizeMB: (imageCacheMaxSizeMB) => set({ imageCacheMaxSizeMB }),
      setImageCacheExpireDays: (imageCacheExpireDays) => set({ imageCacheExpireDays }),
      setContextualSuggestionCounts: (contextualSuggestionCounts) => set({ contextualSuggestionCounts }),
      setDeveloperMode: (developerMode) => set({ developerMode }),
      setHmacSalt: (hmacSalt) => set({ hmacSalt }),
      setServerHost: (serverHost) => set({ serverHost }),
    }),
    { name: 'violet-app-settings' },
  ),
);
