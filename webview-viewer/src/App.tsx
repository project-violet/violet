import React, { useMemo } from 'react';
import './App.css';
import { Image } from './components/image';
import { IImageSet } from './interfaces/image-set';
import { getImageSet } from './utils/image-set';

export default function App() {
    const images = useMemo(
        () => getImageSet(),
        [(globalThis as unknown as IImageSet)?.imageset]
    );

    return (
        <div>
            {images.map((e) => (
                <Image key={e} src={e} />
            ))}
        </div>
    );
}
