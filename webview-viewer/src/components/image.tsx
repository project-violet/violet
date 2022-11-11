import { IImageProps, IOnImageError } from '../interfaces/image';
import styled from 'styled-components';

const MyImage = styled.img`
    width: 100%;
    padding: 0;
    margin: 0;
    display: block;
`;

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
