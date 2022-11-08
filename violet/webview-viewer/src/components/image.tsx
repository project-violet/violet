import { IImageProps, IOnImageError } from '../interfaces/image';

export function Image({ src }: IImageProps) {
    return (
        <img
            className="h-[15rem]"
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
