import { IImageProps, IOnImageError } from '../interfaces/image';
import styled from 'styled-components';
import { MyImage } from '../styles';

export function Image({ src }: IImageProps) {
    return (
        <MyImage
            alt="Violet Sample Image"
            src={src}
            onError={({ currentTarget }: IOnImageError) => {
                // https://stackoverflow.com/a/48222599/11853111

                currentTarget.onerror = null;
                currentTarget.src =
                    '../../img/roxy-migurdia-mushoku-tensei-anime-4K-wallpaper-pc-preview.jpg';
            }}
        />
    );
}
