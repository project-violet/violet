export function shouldShowSearchDropdown(
  isOpen: boolean,
  itemCount: number,
  isLoading: boolean,
  hasSuggestionData: boolean,
  hasSearchToken: boolean,
): boolean {
  if (!isOpen || itemCount === 0) return false;
  return !hasSearchToken || !isLoading || hasSuggestionData;
}