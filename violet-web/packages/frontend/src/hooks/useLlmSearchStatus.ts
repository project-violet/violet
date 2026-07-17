import { useMutation } from '@tanstack/react-query';
import { getLlmSearchStatus } from '../api/llm-search';

export function useLlmSearchStatus() {
  return useMutation({ mutationFn: getLlmSearchStatus });
}
