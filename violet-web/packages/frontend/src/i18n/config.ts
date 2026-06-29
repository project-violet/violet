import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';
import ko from './locales/ko.json';
import ja from './locales/ja.json';
import zh from './locales/zh.json';
import eo from './locales/eo.json';
import it from './locales/it.json';
import pt from './locales/pt.json';

const resources = {
  en: { translation: en },
  ko: { translation: ko },
  ja: { translation: ja },
  zh: { translation: zh },
  eo: { translation: eo },
  it: { translation: it },
  pt: { translation: pt },
};

// Detect system language
const getSystemLanguage = (): string => {
  const browserLang = navigator.language.toLowerCase();

  // Map browser language codes to our supported languages
  if (browserLang.startsWith('ko')) return 'ko';
  if (browserLang.startsWith('ja')) return 'ja';
  if (browserLang.startsWith('zh')) return 'zh';
  if (browserLang.startsWith('eo')) return 'eo';
  if (browserLang.startsWith('it')) return 'it';
  if (browserLang.startsWith('pt')) return 'pt';
  return 'en'; // Default to English
};

// Get initial language from localStorage or system
const getInitialLanguage = (): string => {
  try {
    const stored = localStorage.getItem('violet-viewer-settings');
    if (stored) {
      const settings = JSON.parse(stored);
      const lang = settings.state?.language;
      if (lang && lang !== 'system') {
        return lang;
      }
    }
  } catch (e) {
    // Ignore parse errors
  }
  return getSystemLanguage();
};

i18n.use(initReactI18next).init({
  resources,
  lng: getInitialLanguage(),
  fallbackLng: 'en',
  interpolation: {
    escapeValue: false,
  },
});

export default i18n;
