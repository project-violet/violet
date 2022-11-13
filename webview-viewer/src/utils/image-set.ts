import { IImageSet } from '../interfaces/image-set';

export function hasImageSet(obj: unknown): obj is IImageSet {
    return (obj as unknown as IImageSet).imageset !== undefined;
}

export function getImageSet(): string[] {
    const e = globalThis;

    if (hasImageSet(e)) {
        return e.imageset;
    }

    return '123456'.split('').map((e) => `/test-article/${e}.webp`);
}
