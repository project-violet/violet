export function shouldUseContextualSuggestions(
  contextualCountsEnabled: boolean,
  partial: string,
  contextualBase: string,
): boolean {
  return contextualCountsEnabled && partial.trim().length > 0 && contextualBase.trim().length > 0;
}