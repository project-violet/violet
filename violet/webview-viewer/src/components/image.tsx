import React, { useEffect, useRef, useState } from 'react';
import { IImageProps, IOnImageError } from '../interfaces/image';
import { MyImage } from '../styles';

export const maxRetryCount = 10;

export const ImageWrapper = React.memo(({ src }: IImageProps) => {
    const [retryCount, setRetryCount] = useState(0);
    const [loading, setLoading] = useState(true);

    const isHidden = retryCount >= maxRetryCount;

    const ref = useRef<HTMLImageElement>(null);

    useEffect(() => {
        if (!ref || !ref?.current) {
            return () => {};
        }

        const onLoad = () => {
            setLoading(false);
        };

        ref.current.addEventListener('load', onLoad);

        return () => {
            ref?.current?.removeEventListener('load', onLoad);
        };
    }, [ref]);

    return (
        <>
            {loading && <div style={{ width: '100%', height: '500px' }} />}
            <MyImage
                ref={ref}
                src={src}
                style={{ display: isHidden ? 'none' : 'block' }}
                onError={({ currentTarget }: IOnImageError) => {
                    if (isHidden) {
                        currentTarget.onerror = null;
                    }
                    currentTarget.src = src;
                    setRetryCount(retryCount + 1);
                }}
            />
        </>
    );
});
