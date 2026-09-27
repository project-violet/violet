import type { ImageDimensions } from '@violet-web/shared';

export interface PageBox { top: number; height: number }
export interface ReadingAnchor { page: number; fraction: number; viewportOffset: number; atEnd: boolean }

export function validDimensions(size?: ImageDimensions | null): size is ImageDimensions {
  return !!size && Number.isFinite(size.width) && Number.isFinite(size.height) && size.width > 0 && size.height > 0;
}

// Unlike an intersection percentage, this also finds pages taller than the screen.
export function pageAtOffset(count: number, box: (page: number) => PageBox, offset: number): number {
  let low = 0;
  let high = count - 1;
  while (low < high) {
    const mid = Math.floor((low + high) / 2);
    const current = box(mid);
    if (current.top + current.height <= offset) low = mid + 1;
    else high = mid;
  }
  return Math.max(0, low);
}

export function captureAnchor(count: number, box: (page: number) => PageBox, scrollTop: number, viewportHeight: number, scrollHeight: number): ReadingAnchor {
  const viewportOffset = viewportHeight * 0.35;
  const page = pageAtOffset(count, box, scrollTop + viewportOffset);
  const current = box(page);
  return {
    page,
    fraction: Math.max(0, Math.min(1, (scrollTop + viewportOffset - current.top) / Math.max(1, current.height))),
    viewportOffset,
    atEnd: scrollHeight > viewportHeight && scrollHeight - viewportHeight - scrollTop <= 2,
  };
}

export function restoreAnchor(anchor: ReadingAnchor, box: (page: number) => PageBox, viewportHeight: number, scrollHeight: number): number {
  const maxScroll = Math.max(0, scrollHeight - viewportHeight);
  const current = box(anchor.page);
  return anchor.atEnd ? maxScroll : Math.max(0, Math.min(maxScroll,
    current.top + current.height * anchor.fraction - anchor.viewportOffset));
}
