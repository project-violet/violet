import { useRef, useState } from 'react';
import { IImageProps } from '../interfaces/image';
import { MyImage } from '../styles';

export function Image({ src }: IImageProps) {
    const [minHeight, setMinHeight] = useState(0);
    const imgRef = useRef<HTMLImageElement>(null);

    return (
        <MyImage
            ref={imgRef}
            src={src}
            style={{ minHeight: `${minHeight}px` }}
        />
    );
}
