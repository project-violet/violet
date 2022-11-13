import { test, expect } from 'vitest';
import { IImageSet } from '../../interfaces/image-set';
import { getImageSet, hasImageSet } from '../../utils/image-set';

test('hasImageSet() returns true if given object has imageset field', () => {
    const givenObj = {
        imageset: ['a', 'b', 'c'],
    };

    expect(hasImageSet(givenObj)).toStrictEqual(true);
});

test('hasImageSet() returns false if given object does not have imageset field', () => {
    const givenObj = {
        some: 'any',
    };

    expect(hasImageSet(givenObj)).toStrictEqual(false);
});

test('getImageSet() returns 1-6 test articles if globalThis (on this environment, window) does not have imageset field', () => {
    const expected = [
        '/test-article/1.webp',
        '/test-article/2.webp',
        '/test-article/3.webp',
        '/test-article/4.webp',
        '/test-article/5.webp',
        '/test-article/6.webp',
    ];

    expect(getImageSet()).toStrictEqual(expected);
});

test('getImageSet() returns globalThis.imageset if globalThis has imageset field', () => {
    const injected = ['/test-article/123.webp', '/test-article/456.webp'];

    (globalThis as unknown as IImageSet).imageset = injected;

    expect(getImageSet()).toStrictEqual(injected);

    delete (globalThis as any).imageset;
});
