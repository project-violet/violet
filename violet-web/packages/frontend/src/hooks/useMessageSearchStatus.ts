import { useMutation } from '@tanstack/react-query';
import { getMessageSearchStatus } from '../api/message-search';

export function useMessageSearchStatus() {
  return useMutation({
    mutationFn: (baseUrl: string) => getMessageSearchStatus(baseUrl),
  });
}
